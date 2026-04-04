import { prisma } from '../../lib/prisma.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import type { CreateReconciliationInput, ReconQuery } from './reconciliation.schema.js';

export async function createReconciliation(businessId: string, operatorId: string, input: CreateReconciliationInput) {
  // Fetch dispatch with items
  const dispatch = await prisma.dispatch.findFirst({
    where: { id: input.dispatchId, businessId },
    include: { items: { include: { item: true } } },
  });

  if (!dispatch) throw new NotFoundError('Dispatch', input.dispatchId);
  if (dispatch.status === 'RECONCILED') throw new BadRequestError('Dispatch already reconciled');
  if (dispatch.status !== 'CONFIRMED') throw new BadRequestError('Dispatch must be confirmed before reconciliation');

  // Build dispatch item map: itemId -> { quantity, item }
  const dispatchItemMap = new Map(
    dispatch.items.map(di => [di.itemId, { dispatched: di.quantity, item: di.item }])
  );

  // Calculate losses for each recon item
  const reconItemsData = input.items.map(ri => {
    const dispatchItem = dispatchItemMap.get(ri.itemId);
    if (!dispatchItem) throw new BadRequestError(`Item ${ri.itemId} not found in dispatch`);

    const dispatched = dispatchItem.dispatched;
    const wasted = dispatched - ri.sold - ri.returned;

    if (wasted < 0) {
      throw new BadRequestError(
        `Item ${dispatchItem.item.name}: sold (${ri.sold}) + returned (${ri.returned}) cannot exceed dispatched (${dispatched})`
      );
    }

    // SNAPSHOT the daily margin at reconciliation time
    const allowedMargin = dispatchItem.item.dailyMargin;
    const chargeableLoss = Math.max(0, wasted - allowedMargin);
    const lossAmount = Math.round(chargeableLoss * dispatchItem.item.costPrice * 100) / 100;

    return {
      itemId: ri.itemId,
      dispatched,
      sold: ri.sold,
      returned: ri.returned,
      wasted,
      allowedMargin,
      chargeableLoss,
      lossAmount,
    };
  });

  const totalLoss = Math.round(reconItemsData.reduce((sum, ri) => sum + ri.lossAmount, 0) * 100) / 100;

  const reconciliation = await prisma.$transaction(async (tx) => {
    const recon = await tx.reconciliation.create({
      data: {
        businessId,
        dispatchId: input.dispatchId,
        locationId: input.locationId,
        operatorId,
        date: new Date(input.date),
        totalLoss,
        notes: input.notes,
        items: {
          create: reconItemsData,
        },
      },
      include: { items: { include: { item: true } } },
    });

    await tx.dispatch.update({
      where: { id: input.dispatchId },
      data: { status: 'RECONCILED' },
    });

    return recon;
  });

  eventBus.emit(EVENTS.RECONCILIATION_COMPLETED, { reconciliationId: reconciliation.id, businessId, totalLoss });
  return reconciliation;
}

export async function getReconciliations(businessId: string, query: ReconQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.operatorId) where.operatorId = query.operatorId;
  if (query.startDate || query.endDate) {
    where.date = {} as Record<string, Date>;
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [reconciliations, total] = await Promise.all([
    prisma.reconciliation.findMany({
      where,
      include: {
        items: { include: { item: true } },
        operator: { select: { id: true, name: true } },
        location: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.reconciliation.count({ where }),
  ]);

  return {
    data: reconciliations,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getReconciliationById(businessId: string, id: string) {
  const recon = await prisma.reconciliation.findFirst({
    where: { id, businessId },
    include: {
      items: { include: { item: true } },
      operator: { select: { id: true, name: true } },
      location: { select: { id: true, name: true } },
      dispatch: { include: { items: { include: { item: true } } } },
    },
  });
  if (!recon) throw new NotFoundError('Reconciliation', id);
  return recon;
}
