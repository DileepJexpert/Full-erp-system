import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

const VALID_KDS_TRANSITIONS: Record<string, string[]> = {
  KDS_NEW: ['KDS_PREPARING'],
  KDS_PREPARING: ['KDS_READY'],
  KDS_READY: ['KDS_SERVED'],
  KDS_SERVED: [],
};

interface KdsOrderItemInput {
  itemName: string;
  quantity: number;
  notes?: string;
  itemId?: string;
}

export async function createKdsOrder(
  businessId: string,
  billId: string,
  locationId: string,
  items: KdsOrderItemInput[],
  priority?: number,
  notes?: string,
) {
  if (!items || items.length === 0) {
    throw new BadRequestError('At least one item is required');
  }

  // Auto-assign orderNumber: increment per location per day
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayEnd = new Date(today);
  todayEnd.setHours(23, 59, 59, 999);

  const lastOrder = await prisma.kdsOrder.findFirst({
    where: {
      businessId,
      locationId,
      createdAt: { gte: today, lte: todayEnd },
    },
    orderBy: { orderNumber: 'desc' },
    select: { orderNumber: true },
  });

  const orderNumber = (lastOrder?.orderNumber ?? 0) + 1;

  return prisma.kdsOrder.create({
    data: {
      orderNumber,
      businessId,
      locationId,
      billId,
      priority: priority ?? 0,
      notes,
      items: {
        create: items.map((item) => ({
          itemName: item.itemName,
          quantity: item.quantity,
          notes: item.notes,
          itemId: item.itemId,
        })),
      },
    },
    include: { items: true },
  });
}

export async function getActiveOrders(businessId: string, locationId: string) {
  return prisma.kdsOrder.findMany({
    where: {
      businessId,
      locationId,
      status: { not: 'KDS_SERVED' },
    },
    orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
    include: { items: true },
  });
}

export async function updateOrderStatus(businessId: string, id: string, status: string) {
  const order = await prisma.kdsOrder.findFirst({
    where: { id, businessId },
  });
  if (!order) throw new NotFoundError('KDS Order', id);

  const allowed = VALID_KDS_TRANSITIONS[order.status];
  if (!allowed || !allowed.includes(status)) {
    throw new BadRequestError(
      `Cannot transition from ${order.status} to ${status}`,
    );
  }

  const now = new Date();
  const updateData: Record<string, unknown> = { status };

  if (status === 'KDS_PREPARING') {
    updateData.startedAt = now;
  } else if (status === 'KDS_READY') {
    updateData.readyAt = now;
  } else if (status === 'KDS_SERVED') {
    updateData.servedAt = now;
  }

  return prisma.kdsOrder.update({
    where: { id },
    data: updateData,
    include: { items: true },
  });
}

export async function getOrdersByBill(businessId: string, billId: string) {
  return prisma.kdsOrder.findMany({
    where: { businessId, billId },
    orderBy: { createdAt: 'asc' },
    include: { items: true },
  });
}

export async function getKdsStats(businessId: string, locationId: string, date?: string) {
  const targetDate = date ? new Date(date) : new Date();
  targetDate.setHours(0, 0, 0, 0);
  const endDate = new Date(targetDate);
  endDate.setHours(23, 59, 59, 999);

  const where = {
    businessId,
    locationId,
    createdAt: { gte: targetDate, lte: endDate },
  };

  const [orders, statusCounts] = await Promise.all([
    prisma.kdsOrder.findMany({
      where: {
        ...where,
        startedAt: { not: null },
        readyAt: { not: null },
      },
      select: { startedAt: true, readyAt: true },
    }),
    prisma.kdsOrder.groupBy({
      by: ['status'],
      where,
      _count: { id: true },
    }),
  ]);

  // Calculate average prep time (startedAt -> readyAt) in seconds
  let avgPrepTimeSeconds: number | null = null;
  if (orders.length > 0) {
    const totalMs = orders.reduce((sum, o) => {
      return sum + (o.readyAt!.getTime() - o.startedAt!.getTime());
    }, 0);
    avgPrepTimeSeconds = Math.round(totalMs / orders.length / 1000);
  }

  const totalOrders = statusCounts.reduce((sum, s) => sum + s._count.id, 0);
  const ordersByStatus: Record<string, number> = {};
  for (const s of statusCounts) {
    ordersByStatus[s.status] = s._count.id;
  }

  return {
    totalOrders,
    avgPrepTimeSeconds,
    ordersByStatus,
    completedOrders: orders.length,
  };
}
