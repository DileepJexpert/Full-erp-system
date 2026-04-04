import { prisma } from '../../lib/prisma.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';
import { LOYALTY_POINTS_PER_RUPEE, LOYALTY_REDEEM_THRESHOLD, LOYALTY_REDEEM_VALUE } from '../../config/constants.js';
import type { CustomerQuery, CreateCustomerInput } from './loyalty.schema.js';

export function calculatePointsEarned(billTotal: number): number {
  return Math.floor(billTotal / LOYALTY_POINTS_PER_RUPEE);
}

export function calculateRedemptionDiscount(points: number): number {
  if (points < LOYALTY_REDEEM_THRESHOLD) return 0;
  return Math.floor(points / LOYALTY_REDEEM_THRESHOLD) * LOYALTY_REDEEM_VALUE;
}

export async function getCustomers(businessId: string, query: CustomerQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.search) {
    where.OR = [
      { phone: { contains: query.search } },
      { name: { contains: query.search, mode: 'insensitive' } },
    ];
  }

  const [customers, total] = await Promise.all([
    prisma.customer.findMany({
      where,
      orderBy: { totalSpent: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.customer.count({ where }),
  ]);

  return {
    data: customers,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getCustomerById(businessId: string, id: string) {
  const customer = await prisma.customer.findFirst({
    where: { id, businessId },
    include: { bills: { orderBy: { createdAt: 'desc' }, take: 10 } },
  });
  if (!customer) throw new NotFoundError('Customer', id);
  return customer;
}

export async function createCustomer(businessId: string, input: CreateCustomerInput) {
  return prisma.customer.upsert({
    where: { phone_businessId: { phone: input.phone, businessId } },
    create: { phone: input.phone, name: input.name, businessId },
    update: { name: input.name ?? undefined },
  });
}

export async function getCustomerByPhone(businessId: string, phone: string) {
  const customer = await prisma.customer.findUnique({
    where: { phone_businessId: { phone, businessId } },
  });
  if (!customer) throw new NotFoundError('Customer', `phone:${phone}`);
  return {
    ...customer,
    redeemableDiscount: calculateRedemptionDiscount(customer.loyaltyPoints),
  };
}
