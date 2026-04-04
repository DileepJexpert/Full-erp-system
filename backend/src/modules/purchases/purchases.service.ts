import { prisma } from '../../lib/prisma.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import type { CreatePurchaseInput, PurchaseQuery, RecordPaymentInput } from './purchases.schema.js';

function determinePaymentStatus(amountPaid: number, totalAmount: number): 'PAID' | 'PARTIAL' | 'PENDING' {
  if (amountPaid >= totalAmount) return 'PAID';
  if (amountPaid > 0) return 'PARTIAL';
  return 'PENDING';
}

export async function createPurchase(businessId: string, createdById: string, input: CreatePurchaseInput) {
  // Verify supplier exists
  const supplier = await prisma.supplier.findFirst({
    where: { id: input.supplierId, businessId, isActive: true },
  });
  if (!supplier) throw new NotFoundError('Supplier', input.supplierId);

  // Verify all items exist
  const itemIds = input.items.map((i) => i.itemId);
  const items = await prisma.item.findMany({
    where: { id: { in: itemIds }, businessId },
  });
  if (items.length !== itemIds.length) {
    throw new BadRequestError('One or more items not found');
  }

  // Calculate totals
  const totalAmount = input.items.reduce((sum, i) => sum + i.quantity * i.unitPrice, 0);
  const paymentStatus = determinePaymentStatus(input.amountPaid, totalAmount);

  const purchase = await prisma.$transaction(async (tx) => {
    const newPurchase = await tx.purchase.create({
      data: {
        businessId,
        supplierId: input.supplierId,
        createdById,
        date: new Date(input.date),
        totalAmount,
        amountPaid: input.amountPaid,
        paymentStatus,
        notes: input.notes,
        items: {
          create: input.items.map((i) => ({
            itemId: i.itemId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            lineTotal: i.quantity * i.unitPrice,
          })),
        },
      },
      include: {
        items: { include: { item: true } },
        supplier: { select: { id: true, name: true } },
      },
    });

    // Update central stock for each item
    for (const item of input.items) {
      await tx.item.update({
        where: { id: item.itemId },
        data: { centralStock: { increment: item.quantity } },
      });
    }

    return newPurchase;
  });

  eventBus.emit(EVENTS.PURCHASE_CREATED, { purchaseId: purchase.id, businessId });
  return purchase;
}

export async function getPurchases(businessId: string, query: PurchaseQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.supplierId) where.supplierId = query.supplierId;
  if (query.paymentStatus) where.paymentStatus = query.paymentStatus;
  if (query.startDate || query.endDate) {
    where.date = {};
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [purchases, total] = await Promise.all([
    prisma.purchase.findMany({
      where,
      include: {
        items: { include: { item: true } },
        supplier: { select: { id: true, name: true } },
        createdBy: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.purchase.count({ where }),
  ]);

  return {
    data: purchases,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getPurchaseById(businessId: string, id: string) {
  const purchase = await prisma.purchase.findFirst({
    where: { id, businessId },
    include: {
      items: { include: { item: true } },
      supplier: true,
      createdBy: { select: { id: true, name: true } },
    },
  });
  if (!purchase) throw new NotFoundError('Purchase', id);
  return purchase;
}

export async function recordPayment(businessId: string, id: string, input: RecordPaymentInput) {
  const purchase = await prisma.purchase.findFirst({ where: { id, businessId } });
  if (!purchase) throw new NotFoundError('Purchase', id);

  if (purchase.paymentStatus === 'PAID') {
    throw new BadRequestError('Purchase is already fully paid');
  }

  const newAmountPaid = purchase.amountPaid + input.amount;
  const paymentStatus = determinePaymentStatus(newAmountPaid, purchase.totalAmount);

  return prisma.purchase.update({
    where: { id },
    data: {
      amountPaid: newAmountPaid,
      paymentStatus,
    },
    include: {
      items: { include: { item: true } },
      supplier: { select: { id: true, name: true } },
    },
  });
}
