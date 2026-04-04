import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import type { CreateExpenseInput, ExpenseQuery } from './expenses.schema.js';

export async function createExpense(businessId: string, createdById: string, input: CreateExpenseInput) {
  // Check dailyExpenseLimit on location if set
  const location = await prisma.location.findFirst({
    where: { id: input.locationId, businessId },
  });
  if (!location) throw new NotFoundError('Location', input.locationId);

  if (location.dailyExpenseLimit) {
    const dayStart = new Date(input.date);
    const dayEnd = new Date(input.date);
    dayEnd.setDate(dayEnd.getDate() + 1);

    const aggregate = await prisma.expense.aggregate({
      where: {
        businessId,
        locationId: input.locationId,
        date: { gte: dayStart, lt: dayEnd },
      },
      _sum: { amount: true },
    });

    const currentTotal = aggregate._sum.amount ?? 0;
    if (currentTotal + input.amount > location.dailyExpenseLimit) {
      throw new BadRequestError(
        `Daily expense limit of ${location.dailyExpenseLimit} would be exceeded. Current total: ${currentTotal}, attempted: ${input.amount}`,
      );
    }
  }

  return prisma.expense.create({
    data: {
      businessId,
      locationId: input.locationId,
      createdById,
      date: new Date(input.date),
      amount: input.amount,
      category: input.category as any,
      description: input.description,
      receiptUrl: input.receiptUrl,
    },
    include: { location: { select: { id: true, name: true } } },
  });
}

export async function getExpenses(businessId: string, query: ExpenseQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.category) where.category = query.category;
  if (query.startDate || query.endDate) {
    where.date = {};
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [expenses, total] = await Promise.all([
    prisma.expense.findMany({
      where,
      include: {
        location: { select: { id: true, name: true } },
        createdBy: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.expense.count({ where }),
  ]);

  return {
    data: expenses,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getExpenseById(businessId: string, id: string) {
  const expense = await prisma.expense.findFirst({
    where: { id, businessId },
    include: {
      location: { select: { id: true, name: true } },
      createdBy: { select: { id: true, name: true } },
    },
  });
  if (!expense) throw new NotFoundError('Expense', id);
  return expense;
}

export async function deleteExpense(businessId: string, id: string) {
  const expense = await prisma.expense.findFirst({ where: { id, businessId } });
  if (!expense) throw new NotFoundError('Expense', id);

  return prisma.expense.delete({ where: { id } });
}
