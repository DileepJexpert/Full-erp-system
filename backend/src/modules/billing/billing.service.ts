import { prisma } from '../../lib/prisma.js';
import { calculateBillGst } from '../../utils/gst.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import { LOYALTY_POINTS_PER_RUPEE, LOYALTY_REDEEM_THRESHOLD, LOYALTY_REDEEM_VALUE } from '../../config/constants.js';
import type { CreateBillInput, BillQuery } from './billing.schema.js';

export async function createBill(businessId: string, operatorId: string, input: CreateBillInput) {
  // Fetch items with gstRate
  const itemIds = input.items.map(i => i.itemId);
  const items = await prisma.item.findMany({
    where: { id: { in: itemIds }, businessId },
  });

  if (items.length !== itemIds.length) {
    throw new BadRequestError('One or more items not found');
  }

  const itemMap = new Map(items.map(i => [i.id, i]));

  // Calculate GST
  const gstItems = input.items.map(i => ({
    quantity: i.quantity,
    unitPrice: i.unitPrice,
    gstRate: itemMap.get(i.itemId)!.gstRate,
  }));
  const gstSummary = calculateBillGst(gstItems);

  // Loyalty discount
  let loyaltyDiscount = 0;
  let loyaltyPointsRedeemed = input.loyaltyPointsRedeemed;
  if (loyaltyPointsRedeemed >= LOYALTY_REDEEM_THRESHOLD) {
    loyaltyDiscount = Math.floor(loyaltyPointsRedeemed / LOYALTY_REDEEM_THRESHOLD) * LOYALTY_REDEEM_VALUE;
  } else {
    loyaltyPointsRedeemed = 0;
  }

  const total = Math.round((gstSummary.total - loyaltyDiscount) * 100) / 100;
  const netRevenue = Math.round((total - input.aggregatorCommission) * 100) / 100;
  const loyaltyPointsEarned = Math.floor(total / LOYALTY_POINTS_PER_RUPEE);

  // Find or create customer
  let customerId: string | undefined;
  if (input.customerPhone) {
    const customer = await prisma.customer.upsert({
      where: { phone_businessId: { phone: input.customerPhone, businessId } },
      create: { phone: input.customerPhone, name: input.customerName, businessId },
      update: {},
    });
    customerId = customer.id;

    // Validate loyalty redemption
    if (loyaltyPointsRedeemed > 0 && customer.loyaltyPoints < loyaltyPointsRedeemed) {
      throw new BadRequestError(`Customer only has ${customer.loyaltyPoints} loyalty points`);
    }
  }

  const bill = await prisma.$transaction(async (tx) => {
    const newBill = await tx.bill.create({
      data: {
        businessId,
        locationId: input.locationId,
        operatorId,
        date: new Date(input.date),
        subtotal: gstSummary.subtotal,
        cgstAmount: gstSummary.cgstAmount,
        sgstAmount: gstSummary.sgstAmount,
        total,
        paymentMode: input.paymentMode as any,
        cashAmount: input.cashAmount,
        upiAmount: input.upiAmount,
        upiTransactionRef: input.upiTransactionRef,
        orderSource: input.orderSource as any,
        aggregatorOrderId: input.aggregatorOrderId,
        aggregatorCommission: input.aggregatorCommission,
        netRevenue,
        loyaltyPointsEarned,
        loyaltyPointsRedeemed,
        loyaltyDiscount,
        customerPhone: input.customerPhone,
        customerName: input.customerName,
        customerId,
        notes: input.notes,
        items: {
          create: input.items.map(i => ({
            itemId: i.itemId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            lineTotal: i.quantity * i.unitPrice,
          })),
        },
      },
      include: { items: { include: { item: true } } },
    });

    // Update customer stats
    if (customerId) {
      await tx.customer.update({
        where: { id: customerId },
        data: {
          totalVisits: { increment: 1 },
          totalSpent: { increment: total },
          loyaltyPoints: { increment: loyaltyPointsEarned - loyaltyPointsRedeemed },
          lifetimePoints: { increment: loyaltyPointsEarned },
        },
      });
    }

    return newBill;
  });

  eventBus.emit(EVENTS.BILL_CREATED, { billId: bill.id, businessId });
  return bill;
}

export async function getBills(businessId: string, query: BillQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.date) where.date = new Date(query.date);
  if (query.startDate || query.endDate) {
    where.date = {};
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [bills, total] = await Promise.all([
    prisma.bill.findMany({
      where,
      include: { items: { include: { item: true } }, operator: { select: { id: true, name: true } } },
      orderBy: { createdAt: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.bill.count({ where }),
  ]);

  return {
    data: bills,
    pagination: {
      page: query.page,
      limit: query.limit,
      total,
      totalPages: Math.ceil(total / query.limit),
    },
  };
}

export async function getBillById(businessId: string, billId: string) {
  const bill = await prisma.bill.findFirst({
    where: { id: billId, businessId },
    include: {
      items: { include: { item: true } },
      operator: { select: { id: true, name: true } },
      location: { select: { id: true, name: true } },
      customer: true,
    },
  });
  if (!bill) throw new NotFoundError('Bill', billId);
  return bill;
}
