import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError, ConflictError } from '../../utils/errors.js';
import { getMonthRange } from '../../utils/format.js';
import type { ComputeSalaryInput, SalaryQuery } from './salary.schema.js';

export async function computeSalary(businessId: string, input: ComputeSalaryInput) {
  const { start, end } = getMonthRange(input.month);

  // Fetch operator and verify they belong to this business
  const operator = await prisma.user.findFirst({
    where: { id: input.operatorId, businessId },
  });
  if (!operator) throw new NotFoundError('Operator', input.operatorId);

  const baseSalary = operator.baseSalary;

  // Sum totalLoss from reconciliations where the location's staffId = operatorId
  const lossAgg = await prisma.reconciliation.aggregate({
    _sum: { totalLoss: true },
    where: {
      businessId,
      date: { gte: start, lte: end },
      location: { staffId: input.operatorId },
    },
  });
  const totalLossDed = lossAgg._sum.totalLoss ?? 0;

  // Sum shortage from cash collections where operatorId matches
  const cashAgg = await prisma.cashCollection.aggregate({
    _sum: { shortage: true },
    where: {
      businessId,
      operatorId: input.operatorId,
      date: { gte: start, lte: end },
    },
  });
  const totalCashShort = cashAgg._sum.shortage ?? 0;

  // Sum advances where operatorId matches
  const advanceAgg = await prisma.advance.aggregate({
    _sum: { amount: true },
    where: {
      businessId,
      operatorId: input.operatorId,
      date: { gte: start, lte: end },
    },
  });
  const totalAdvanceDed = advanceAgg._sum.amount ?? 0;

  const netSalary = Math.max(
    0,
    baseSalary - totalLossDed - totalCashShort - totalAdvanceDed + input.bonus + input.adjustments,
  );

  // Upsert the salary record (unique on operatorId + month)
  const salary = await prisma.salaryRecord.upsert({
    where: {
      operatorId_month: {
        operatorId: input.operatorId,
        month: input.month,
      },
    },
    update: {
      baseSalary,
      totalLossDed,
      totalCashShort,
      totalAdvanceDed,
      bonus: input.bonus,
      adjustments: input.adjustments,
      adjustmentNotes: input.adjustmentNotes,
      netSalary,
      status: 'DRAFT',
    },
    create: {
      businessId,
      operatorId: input.operatorId,
      month: input.month,
      baseSalary,
      totalLossDed,
      totalCashShort,
      totalAdvanceDed,
      bonus: input.bonus,
      adjustments: input.adjustments,
      adjustmentNotes: input.adjustmentNotes,
      netSalary,
      status: 'DRAFT',
    },
    include: {
      operator: { select: { id: true, name: true } },
    },
  });

  return salary;
}

export async function getSalaryRecords(businessId: string, query: SalaryQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.month) where.month = query.month;
  if (query.status) where.status = query.status;

  const [data, total] = await Promise.all([
    prisma.salaryRecord.findMany({
      where,
      include: {
        operator: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.salaryRecord.count({ where }),
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

export async function finalizeSalary(businessId: string, id: string) {
  const salary = await prisma.salaryRecord.findFirst({
    where: { id, businessId },
  });
  if (!salary) throw new NotFoundError('SalaryRecord', id);
  if (salary.status !== 'DRAFT') {
    throw new ConflictError(`Salary record is already ${salary.status}`);
  }

  return prisma.salaryRecord.update({
    where: { id },
    data: { status: 'FINALIZED' },
    include: {
      operator: { select: { id: true, name: true } },
    },
  });
}

export async function markPaid(businessId: string, id: string) {
  const salary = await prisma.salaryRecord.findFirst({
    where: { id, businessId },
  });
  if (!salary) throw new NotFoundError('SalaryRecord', id);
  if (salary.status === 'PAID') {
    throw new ConflictError('Salary record is already paid');
  }
  if (salary.status !== 'FINALIZED') {
    throw new BadRequestError('Salary must be finalized before marking as paid');
  }

  return prisma.salaryRecord.update({
    where: { id },
    data: { status: 'PAID', paidAt: new Date() },
    include: {
      operator: { select: { id: true, name: true } },
    },
  });
}

export async function addAdvance(
  businessId: string,
  operatorId: string,
  amount: number,
  date: string,
  notes?: string,
) {
  // Verify operator belongs to business
  const operator = await prisma.user.findFirst({
    where: { id: operatorId, businessId },
  });
  if (!operator) throw new NotFoundError('Operator', operatorId);

  return prisma.advance.create({
    data: {
      businessId,
      operatorId,
      amount,
      date: new Date(date),
      notes,
    },
  });
}
