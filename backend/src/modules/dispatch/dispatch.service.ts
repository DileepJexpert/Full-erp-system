import { prisma } from '../../lib/prisma.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import type { CreateDispatchInput, DispatchQuery } from './dispatch.schema.js';

export async function createDispatch(businessId: string, createdById: string, input: CreateDispatchInput) {
  // Check for duplicate dispatch (same location + date)
  const existing = await prisma.dispatch.findUnique({
    where: { locationId_date: { locationId: input.locationId, date: new Date(input.date) } },
  });
  if (existing) {
    throw new BadRequestError('Dispatch already exists for this location and date');
  }

  // Verify all items exist and deduct central stock
  const itemIds = input.items.map((i) => i.itemId);
  const items = await prisma.item.findMany({ where: { id: { in: itemIds }, businessId } });
  if (items.length !== itemIds.length) {
    throw new BadRequestError('One or more items not found');
  }

  const dispatch = await prisma.$transaction(async (tx) => {
    const newDispatch = await tx.dispatch.create({
      data: {
        businessId,
        locationId: input.locationId,
        createdById,
        date: new Date(input.date),
        notes: input.notes,
        items: {
          create: input.items.map((i) => ({
            itemId: i.itemId,
            quantity: i.quantity,
          })),
        },
      },
      include: { items: { include: { item: true } }, location: true },
    });

    // Deduct central stock
    for (const item of input.items) {
      const updated = await tx.item.update({
        where: { id: item.itemId },
        data: { centralStock: { decrement: item.quantity } },
      });

      // Check low stock alert
      if (updated.minStockLevel && updated.centralStock < updated.minStockLevel) {
        await tx.alert.create({
          data: {
            businessId,
            type: 'LOW_STOCK',
            severity: 'WARNING',
            title: `Low stock: ${updated.name}`,
            description: `Central stock (${updated.centralStock} ${updated.unit}) is below minimum level (${updated.minStockLevel} ${updated.unit})`,
            data: { itemId: updated.id, currentStock: updated.centralStock, minLevel: updated.minStockLevel },
          },
        });
      }
    }

    return newDispatch;
  });

  eventBus.emit(EVENTS.DISPATCH_CREATED, { dispatchId: dispatch.id, businessId });
  return dispatch;
}

export async function confirmDispatch(businessId: string, dispatchId: string) {
  const dispatch = await prisma.dispatch.findFirst({
    where: { id: dispatchId, businessId },
  });
  if (!dispatch) throw new NotFoundError('Dispatch', dispatchId);
  if (dispatch.status !== 'PENDING') throw new BadRequestError('Dispatch is not in PENDING status');

  return prisma.dispatch.update({
    where: { id: dispatchId },
    data: { status: 'CONFIRMED' },
    include: { items: { include: { item: true } }, location: true },
  });
}

export async function getDispatches(businessId: string, query: DispatchQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.status) where.status = query.status;
  if (query.date) where.date = new Date(query.date);
  if (query.startDate || query.endDate) {
    where.date = {};
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [dispatches, total] = await Promise.all([
    prisma.dispatch.findMany({
      where,
      include: {
        items: { include: { item: true } },
        location: { select: { id: true, name: true } },
        createdBy: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.dispatch.count({ where }),
  ]);

  return {
    data: dispatches,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getDispatchById(businessId: string, id: string) {
  const dispatch = await prisma.dispatch.findFirst({
    where: { id, businessId },
    include: {
      items: { include: { item: true } },
      location: true,
      createdBy: { select: { id: true, name: true } },
      reconciliation: { include: { items: true } },
    },
  });
  if (!dispatch) throw new NotFoundError('Dispatch', id);
  return dispatch;
}

export async function prefillFromTemplate(businessId: string, locationId: string) {
  const location = await prisma.location.findFirst({
    where: { id: locationId, businessId },
    include: {
      activeTemplate: {
        include: { items: { include: { item: true } } },
      },
    },
  });

  if (!location) throw new NotFoundError('Location', locationId);
  if (!location.activeTemplate) return { items: [] };

  return {
    items: location.activeTemplate.items.map((ti) => ({
      itemId: ti.itemId,
      itemName: ti.item.name,
      unit: ti.item.unit,
      defaultQty: ti.defaultQty,
      costPrice: ti.item.costPrice,
      sellPrice: ti.item.sellPrice,
    })),
  };
}
