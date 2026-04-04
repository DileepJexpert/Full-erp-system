import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';

export interface VarianceResult {
  month: string;
  locationId: string;
  budget: {
    revenueTarget: number;
    cogsLimit: number;
    expenseLimit: number;
    salaryBudget: number;
    profitTarget: number;
  };
  actual: {
    revenue: number;
    expenses: number;
    salary: number;
  };
  variance: {
    revenue: number;
    revenuePercent: number;
    expenses: number;
    expensesPercent: number;
    salary: number;
    salaryPercent: number;
  };
}

/**
 * Calculate budget vs actual variance for a given month.
 * Month format: "YYYY-MM"
 */
export async function calculateVariance(
  businessId: string,
  month: string,
  locationId?: string,
): Promise<VarianceResult[]> {
  // Parse month boundaries
  const [yearStr, monthStr] = month.split('-');
  const year = parseInt(yearStr, 10);
  const monthNum = parseInt(monthStr, 10);
  const monthStart = new Date(year, monthNum - 1, 1);
  const monthEnd = new Date(year, monthNum, 0, 23, 59, 59);

  // Fetch budgets
  const budgetWhere: Record<string, unknown> = { businessId, month };
  if (locationId) budgetWhere.locationId = locationId;

  const budgets = await prisma.budget.findMany({ where: budgetWhere });

  if (budgets.length === 0) {
    throw new NotFoundError('Budget', `month=${month}`);
  }

  const results: VarianceResult[] = [];

  for (const budget of budgets) {
    const locId = budget.locationId;

    // Actual revenue: sum of Bill.total for this location & month
    const revenueAgg = await prisma.bill.aggregate({
      where: {
        businessId,
        locationId: locId,
        date: { gte: monthStart, lte: monthEnd },
      },
      _sum: { total: true },
    });
    const actualRevenue = revenueAgg._sum.total ?? 0;

    // Actual expenses: sum of Expense.amount for this location & month
    const expenseAgg = await prisma.expense.aggregate({
      where: {
        businessId,
        locationId: locId,
        date: { gte: monthStart, lte: monthEnd },
      },
      _sum: { amount: true },
    });
    const actualExpenses = expenseAgg._sum.amount ?? 0;

    // Actual salary: sum of SalaryRecord.netSalary for this month
    // SalaryRecord uses month as "YYYY-MM" string, and is per operator (not per location)
    const salaryAgg = await prisma.salaryRecord.aggregate({
      where: {
        businessId,
        month,
      },
      _sum: { netSalary: true },
    });
    const actualSalary = salaryAgg._sum.netSalary ?? 0;

    const revenueVariance = actualRevenue - budget.revenueTarget;
    const expenseVariance = actualExpenses - budget.expenseLimit;
    const salaryVariance = actualSalary - budget.salaryBudget;

    results.push({
      month,
      locationId: locId,
      budget: {
        revenueTarget: budget.revenueTarget,
        cogsLimit: budget.cogsLimit,
        expenseLimit: budget.expenseLimit,
        salaryBudget: budget.salaryBudget,
        profitTarget: budget.profitTarget,
      },
      actual: {
        revenue: actualRevenue,
        expenses: actualExpenses,
        salary: actualSalary,
      },
      variance: {
        revenue: revenueVariance,
        revenuePercent: budget.revenueTarget !== 0
          ? Math.round((revenueVariance / budget.revenueTarget) * 10000) / 100
          : 0,
        expenses: expenseVariance,
        expensesPercent: budget.expenseLimit !== 0
          ? Math.round((expenseVariance / budget.expenseLimit) * 10000) / 100
          : 0,
        salary: salaryVariance,
        salaryPercent: budget.salaryBudget !== 0
          ? Math.round((salaryVariance / budget.salaryBudget) * 10000) / 100
          : 0,
      },
    });
  }

  return results;
}
