import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

interface CreditLedgerFilters {
  startDate?: string;
  endDate?: string;
  page?: number;
  limit?: number;
}

export async function addCreditSale(
  businessId: string,
  customerId: string,
  amount: number,
  billId: string,
  locationId: string,
  userId: string,
) {
  if (amount <= 0) {
    throw new BadRequestError('Credit sale amount must be positive');
  }

  const customer = await prisma.customer.findFirst({
    where: { id: customerId, businessId },
  });

  if (!customer) {
    throw new NotFoundError('Customer', customerId);
  }

  const newBalance = customer.creditBalance + amount;

  return prisma.$transaction(async (tx) => {
    await tx.customer.update({
      where: { id: customerId },
      data: { creditBalance: newBalance },
    });

    const txn = await tx.creditTransaction.create({
      data: {
        date: new Date(),
        type: 'CREDIT_SALE',
        amount,
        runningBalance: newBalance,
        description: `Credit sale for bill ${billId}`,
        billId,
        businessId,
        customerId,
        locationId,
        recordedById: userId,
      },
    });

    return txn;
  });
}

export async function receivePayment(
  businessId: string,
  customerId: string,
  amount: number,
  paymentMode: string,
  paymentRef: string | undefined,
  userId: string,
) {
  if (amount <= 0) {
    throw new BadRequestError('Payment amount must be positive');
  }

  const customer = await prisma.customer.findFirst({
    where: { id: customerId, businessId },
  });

  if (!customer) {
    throw new NotFoundError('Customer', customerId);
  }

  if (amount > customer.creditBalance) {
    throw new BadRequestError(
      `Payment amount (${amount}) exceeds outstanding balance (${customer.creditBalance})`,
    );
  }

  const newBalance = customer.creditBalance - amount;

  return prisma.$transaction(async (tx) => {
    await tx.customer.update({
      where: { id: customerId },
      data: { creditBalance: newBalance },
    });

    const txn = await tx.creditTransaction.create({
      data: {
        date: new Date(),
        type: 'PAYMENT_RECEIVED',
        amount,
        runningBalance: newBalance,
        description: `Payment received via ${paymentMode}`,
        paymentMode: paymentMode as any,
        paymentRef,
        businessId,
        customerId,
        recordedById: userId,
      },
    });

    return txn;
  });
}

export async function getCreditLedger(
  businessId: string,
  customerId: string,
  filters: CreditLedgerFilters,
) {
  const customer = await prisma.customer.findFirst({
    where: { id: customerId, businessId },
  });

  if (!customer) {
    throw new NotFoundError('Customer', customerId);
  }

  const page = filters.page ?? 1;
  const limit = filters.limit ?? 50;
  const skip = (page - 1) * limit;

  const where: Record<string, unknown> = { businessId, customerId };

  if (filters.startDate || filters.endDate) {
    const dateFilter: Record<string, Date> = {};
    if (filters.startDate) dateFilter.gte = new Date(filters.startDate);
    if (filters.endDate) dateFilter.lte = new Date(filters.endDate);
    where.date = dateFilter;
  }

  const [transactions, total] = await Promise.all([
    prisma.creditTransaction.findMany({
      where,
      orderBy: { date: 'desc' },
      skip,
      take: limit,
    }),
    prisma.creditTransaction.count({ where }),
  ]);

  return {
    customer: {
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      creditBalance: customer.creditBalance,
    },
    data: transactions,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };
}

export async function getOutstandingCustomers(businessId: string) {
  const customers = await prisma.customer.findMany({
    where: {
      businessId,
      creditBalance: { gt: 0 },
    },
    select: {
      id: true,
      name: true,
      phone: true,
      creditBalance: true,
    },
    orderBy: { creditBalance: 'desc' },
  });

  const totalOutstanding = customers.reduce((sum, c) => sum + c.creditBalance, 0);

  return {
    totalOutstanding,
    count: customers.length,
    customers,
  };
}

export async function getCustomerCreditSummary(businessId: string, customerId: string) {
  const customer = await prisma.customer.findFirst({
    where: { id: customerId, businessId },
  });

  if (!customer) {
    throw new NotFoundError('Customer', customerId);
  }

  const lastPayment = await prisma.creditTransaction.findFirst({
    where: { businessId, customerId, type: 'PAYMENT_RECEIVED' },
    orderBy: { date: 'desc' },
  });

  let daysSinceLastPayment: number | null = null;
  if (lastPayment) {
    const diffMs = Date.now() - lastPayment.date.getTime();
    daysSinceLastPayment = Math.floor(diffMs / (1000 * 60 * 60 * 24));
  }

  const totalCreditSales = await prisma.creditTransaction.aggregate({
    where: { businessId, customerId, type: 'CREDIT_SALE' },
    _sum: { amount: true },
  });

  const totalPayments = await prisma.creditTransaction.aggregate({
    where: { businessId, customerId, type: 'PAYMENT_RECEIVED' },
    _sum: { amount: true },
  });

  return {
    customerId: customer.id,
    customerName: customer.name,
    customerPhone: customer.phone,
    totalOwed: customer.creditBalance,
    totalCreditSales: totalCreditSales._sum.amount ?? 0,
    totalPayments: totalPayments._sum.amount ?? 0,
    lastPaymentDate: lastPayment?.date ?? null,
    daysSinceLastPayment,
  };
}
