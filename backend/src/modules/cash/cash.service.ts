import { prisma } from '../../lib/prisma.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { NotFoundError } from '../../utils/errors.js';
import type { RecordCashInput, CashQuery } from './cash.schema.js';

export async function recordCash(businessId: string, collectedById: string, input: RecordCashInput) {
  const shortage = Math.max(0, input.expectedCash - input.actualCollected);

  const cashCollection = await prisma.cashCollection.create({
    data: {
      businessId,
      locationId: input.locationId,
      operatorId: input.operatorId,
      collectedById,
      date: new Date(input.date),
      expectedCash: input.expectedCash,
      actualCollected: input.actualCollected,
      shortage,
      depositedAmount: input.depositedAmount,
      bankRef: input.bankRef,
      notes: input.notes,
    },
    include: {
      location: { select: { id: true, name: true } },
      operator: { select: { id: true, name: true } },
      collectedBy: { select: { id: true, name: true } },
    },
  });

  eventBus.emit(EVENTS.CASH_COLLECTED, {
    cashCollectionId: cashCollection.id,
    businessId,
    locationId: input.locationId,
    shortage,
  });

  return cashCollection;
}

export async function getCashCollections(businessId: string, query: CashQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.operatorId) where.operatorId = query.operatorId;
  if (query.startDate || query.endDate) {
    where.date = {} as Record<string, Date>;
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [data, total] = await Promise.all([
    prisma.cashCollection.findMany({
      where,
      include: {
        location: { select: { id: true, name: true } },
        operator: { select: { id: true, name: true } },
        collectedBy: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.cashCollection.count({ where }),
  ]);

  return {
    data,
    pagination: {
      page: query.page,
      limit: query.limit,
      total,
      totalPages: Math.ceil(total / query.limit),
    },
  };
}

export async function getCashById(businessId: string, id: string) {
  const cash = await prisma.cashCollection.findFirst({
    where: { id, businessId },
    include: {
      location: { select: { id: true, name: true } },
      operator: { select: { id: true, name: true } },
      collectedBy: { select: { id: true, name: true } },
    },
  });
  if (!cash) throw new NotFoundError('CashCollection', id);
  return cash;
}
