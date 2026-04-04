import { prisma } from '../../lib/prisma.js';

// ─── Daily Summary ────────────────────────────────────────────

export async function generateDailySummary(businessId: string, date: Date) {
  const dayStart = new Date(date);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(date);
  dayEnd.setHours(23, 59, 59, 999);

  // Fetch all bills for the day
  const bills = await prisma.bill.findMany({
    where: {
      businessId,
      date: { gte: dayStart, lte: dayEnd },
    },
    include: { items: { include: { item: true } } },
  });

  const totalRevenue = bills.reduce((sum, b) => sum + b.total, 0);
  const cashTotal = bills.reduce((sum, b) => sum + b.cashAmount, 0);
  const upiTotal = bills.reduce((sum, b) => sum + b.upiAmount, 0);
  const billCount = bills.length;

  // Top items by quantity sold
  const itemMap = new Map<string, { name: string; qty: number; revenue: number }>();
  for (const bill of bills) {
    for (const bi of bill.items) {
      const existing = itemMap.get(bi.itemId) ?? { name: bi.item.name, qty: 0, revenue: 0 };
      existing.qty += bi.quantity;
      existing.revenue += bi.lineTotal;
      itemMap.set(bi.itemId, existing);
    }
  }
  const topItems = [...itemMap.values()]
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 10);

  // Pending reconciliation count
  const pendingRecon = await prisma.reconciliation.count({
    where: {
      businessId,
      date: { gte: dayStart, lte: dayEnd },
      status: { not: 'COMPLETED' },
    },
  });

  return {
    reportType: 'daily_summary',
    date: dayStart.toISOString().split('T')[0],
    totalRevenue,
    billCount,
    paymentSplit: {
      cash: cashTotal,
      upi: upiTotal,
    },
    pendingReconciliations: pendingRecon,
    topItems,
  };
}

// ─── Weekly P&L ───────────────────────────────────────────────

export async function generateWeeklyPL(businessId: string, weekStart: Date) {
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 6);
  weekEnd.setHours(23, 59, 59, 999);

  const locations = await prisma.location.findMany({
    where: { businessId, isActive: true },
    select: { id: true, name: true },
  });

  const locationPL = [];

  for (const loc of locations) {
    // Revenue from bills
    const billAgg = await prisma.bill.aggregate({
      where: {
        businessId,
        locationId: loc.id,
        date: { gte: weekStart, lte: weekEnd },
      },
      _sum: { total: true, netRevenue: true },
    });
    const revenue = billAgg._sum.netRevenue ?? billAgg._sum.total ?? 0;

    // COGS from purchases
    const purchaseAgg = await prisma.purchase.aggregate({
      where: {
        businessId,
        locationId: loc.id,
        date: { gte: weekStart, lte: weekEnd },
      },
      _sum: { totalAmount: true },
    });
    const cogs = purchaseAgg._sum.totalAmount ?? 0;

    // Expenses
    const expenseAgg = await prisma.expense.aggregate({
      where: {
        businessId,
        locationId: loc.id,
        date: { gte: weekStart, lte: weekEnd },
      },
      _sum: { amount: true },
    });
    const expenses = expenseAgg._sum.amount ?? 0;

    // Salary (pro-rated weekly estimate: monthly / 4)
    const salaryAgg = await prisma.salaryRecord.aggregate({
      where: {
        businessId,
        operator: { assignedLocation: { id: loc.id } },
        status: { in: ['FINALIZED', 'PAID'] },
      },
      _sum: { netSalary: true },
    });
    const salaryWeekly = (salaryAgg._sum.netSalary ?? 0) / 4;

    const profit = revenue - cogs - expenses - salaryWeekly;

    locationPL.push({
      locationId: loc.id,
      locationName: loc.name,
      revenue,
      cogs,
      expenses,
      salary: Math.round(salaryWeekly * 100) / 100,
      profit: Math.round(profit * 100) / 100,
    });
  }

  return {
    reportType: 'weekly_pl',
    weekStart: weekStart.toISOString().split('T')[0],
    weekEnd: weekEnd.toISOString().split('T')[0],
    locations: locationPL,
    totalProfit: Math.round(locationPL.reduce((s, l) => s + l.profit, 0) * 100) / 100,
  };
}

// ─── Monthly Review ───────────────────────────────────────────

export async function generateMonthlyReview(businessId: string, month: string) {
  // month format: "2025-03"
  const [year, mon] = month.split('-').map(Number);
  const monthStart = new Date(year, mon - 1, 1);
  const monthEnd = new Date(year, mon, 0, 23, 59, 59, 999);

  // Revenue
  const billAgg = await prisma.bill.aggregate({
    where: {
      businessId,
      date: { gte: monthStart, lte: monthEnd },
    },
    _sum: { total: true, netRevenue: true, cashAmount: true, upiAmount: true },
    _count: true,
  });
  const totalRevenue = billAgg._sum.netRevenue ?? billAgg._sum.total ?? 0;

  // Purchases
  const purchaseAgg = await prisma.purchase.aggregate({
    where: {
      businessId,
      date: { gte: monthStart, lte: monthEnd },
    },
    _sum: { totalAmount: true },
    _count: true,
  });

  // Expenses
  const expenseAgg = await prisma.expense.aggregate({
    where: {
      businessId,
      date: { gte: monthStart, lte: monthEnd },
    },
    _sum: { amount: true },
    _count: true,
  });

  // Salary
  const salaryAgg = await prisma.salaryRecord.aggregate({
    where: {
      businessId,
      month,
    },
    _sum: { netSalary: true },
    _count: true,
  });

  // Customer stats
  const newCustomers = await prisma.customer.count({
    where: {
      businessId,
      createdAt: { gte: monthStart, lte: monthEnd },
    },
  });

  // Revenue by order source
  const bills = await prisma.bill.findMany({
    where: {
      businessId,
      date: { gte: monthStart, lte: monthEnd },
    },
    select: { orderSource: true, total: true },
  });
  const revenueBySource: Record<string, number> = {};
  for (const b of bills) {
    revenueBySource[b.orderSource] = (revenueBySource[b.orderSource] ?? 0) + b.total;
  }

  const totalCogs = purchaseAgg._sum.totalAmount ?? 0;
  const totalExpenses = expenseAgg._sum.amount ?? 0;
  const totalSalary = salaryAgg._sum.netSalary ?? 0;
  const netProfit = totalRevenue - totalCogs - totalExpenses - totalSalary;

  return {
    reportType: 'monthly_review',
    month,
    revenue: {
      total: totalRevenue,
      cash: billAgg._sum.cashAmount ?? 0,
      upi: billAgg._sum.upiAmount ?? 0,
      billCount: billAgg._count,
      bySource: revenueBySource,
    },
    costs: {
      cogs: totalCogs,
      purchaseCount: purchaseAgg._count,
      expenses: totalExpenses,
      expenseCount: expenseAgg._count,
      salary: totalSalary,
      staffCount: salaryAgg._count,
    },
    netProfit: Math.round(netProfit * 100) / 100,
    profitMargin: totalRevenue > 0
      ? Math.round((netProfit / totalRevenue) * 10000) / 100
      : 0,
    newCustomers,
  };
}

// ─── GST Summary ──────────────────────────────────────────────

export async function generateGSTSummary(businessId: string, month: string) {
  const [year, mon] = month.split('-').map(Number);
  const monthStart = new Date(year, mon - 1, 1);
  const monthEnd = new Date(year, mon, 0, 23, 59, 59, 999);

  const billItems = await prisma.billItem.findMany({
    where: {
      bill: {
        businessId,
        date: { gte: monthStart, lte: monthEnd },
      },
    },
    include: {
      item: { select: { gstRate: true, hsnCode: true, name: true } },
    },
  });

  // Group by GST rate slab
  const slabMap = new Map<
    number,
    { taxableValue: number; cgst: number; sgst: number; itemCount: number }
  >();

  for (const bi of billItems) {
    const rate = bi.item.gstRate;
    const taxableValue = bi.lineTotal / (1 + rate / 100);
    const gstAmount = bi.lineTotal - taxableValue;
    const cgst = gstAmount / 2;
    const sgst = gstAmount / 2;

    const existing = slabMap.get(rate) ?? { taxableValue: 0, cgst: 0, sgst: 0, itemCount: 0 };
    existing.taxableValue += taxableValue;
    existing.cgst += cgst;
    existing.sgst += sgst;
    existing.itemCount += 1;
    slabMap.set(rate, existing);
  }

  const slabs = [...slabMap.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([rate, data]) => ({
      gstRate: rate,
      taxableValue: Math.round(data.taxableValue * 100) / 100,
      cgst: Math.round(data.cgst * 100) / 100,
      sgst: Math.round(data.sgst * 100) / 100,
      totalTax: Math.round((data.cgst + data.sgst) * 100) / 100,
      itemCount: data.itemCount,
    }));

  const totalTaxable = slabs.reduce((s, sl) => s + sl.taxableValue, 0);
  const totalCGST = slabs.reduce((s, sl) => s + sl.cgst, 0);
  const totalSGST = slabs.reduce((s, sl) => s + sl.sgst, 0);

  return {
    reportType: 'gst_summary',
    month,
    slabs,
    totals: {
      taxableValue: Math.round(totalTaxable * 100) / 100,
      cgst: Math.round(totalCGST * 100) / 100,
      sgst: Math.round(totalSGST * 100) / 100,
      totalTax: Math.round((totalCGST + totalSGST) * 100) / 100,
    },
  };
}
