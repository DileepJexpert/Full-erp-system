import { prisma } from '../../lib/prisma.js';
import { formatRupee } from '../../utils/format.js';

export async function getPnlReport(businessId: string, startDate: Date, endDate: Date) {
  const [revenue, expenses, purchases, reconLoss] = await Promise.all([
    prisma.bill.aggregate({
      where: { businessId, date: { gte: startDate, lte: endDate } },
      _sum: { total: true, cgstAmount: true, sgstAmount: true, subtotal: true, aggregatorCommission: true },
    }),
    prisma.expense.aggregate({
      where: { businessId, date: { gte: startDate, lte: endDate } },
      _sum: { amount: true },
    }),
    prisma.purchase.aggregate({
      where: { businessId, date: { gte: startDate, lte: endDate } },
      _sum: { totalAmount: true },
    }),
    prisma.reconciliation.aggregate({
      where: { businessId, date: { gte: startDate, lte: endDate } },
      _sum: { totalLoss: true },
    }),
  ]);

  const totalRevenue = revenue._sum.total ?? 0;
  const totalSubtotal = revenue._sum.subtotal ?? 0;
  const totalCgst = revenue._sum.cgstAmount ?? 0;
  const totalSgst = revenue._sum.sgstAmount ?? 0;
  const totalCommissions = revenue._sum.aggregatorCommission ?? 0;
  const totalExpenses = expenses._sum.amount ?? 0;
  const totalPurchases = purchases._sum.totalAmount ?? 0;
  const totalLoss = reconLoss._sum.totalLoss ?? 0;

  const grossProfit = totalSubtotal - totalPurchases;
  const netProfit = grossProfit - totalExpenses - totalLoss - totalCommissions;

  return {
    period: { startDate, endDate },
    revenue: {
      total: totalRevenue,
      subtotal: totalSubtotal,
      cgst: totalCgst,
      sgst: totalSgst,
      commissions: totalCommissions,
    },
    costs: {
      purchases: totalPurchases,
      expenses: totalExpenses,
      wasteLoss: totalLoss,
    },
    grossProfit,
    netProfit,
    formatted: {
      revenue: formatRupee(totalRevenue),
      netProfit: formatRupee(netProfit),
    },
  };
}

export async function getGstReport(businessId: string, startDate: Date, endDate: Date) {
  const bills = await prisma.bill.findMany({
    where: { businessId, date: { gte: startDate, lte: endDate } },
    include: { items: { include: { item: true } }, location: { select: { name: true } } },
    orderBy: { date: 'asc' },
  });

  const gstByRate = new Map<number, { taxable: number; cgst: number; sgst: number }>();

  for (const bill of bills) {
    for (const bi of bill.items) {
      const rate = bi.item.gstRate;
      const existing = gstByRate.get(rate) ?? { taxable: 0, cgst: 0, sgst: 0 };
      const lineTotal = bi.lineTotal;
      const halfRate = rate / 2 / 100;
      existing.taxable += lineTotal;
      existing.cgst += lineTotal * halfRate;
      existing.sgst += lineTotal * halfRate;
      gstByRate.set(rate, existing);
    }
  }

  return {
    period: { startDate, endDate },
    totalBills: bills.length,
    gstBreakdown: Array.from(gstByRate.entries()).map(([rate, data]) => ({
      gstRate: rate,
      taxableAmount: Math.round(data.taxable * 100) / 100,
      cgst: Math.round(data.cgst * 100) / 100,
      sgst: Math.round(data.sgst * 100) / 100,
      total: Math.round((data.cgst + data.sgst) * 100) / 100,
    })),
  };
}

export async function exportBillsCsv(businessId: string, startDate: Date, endDate: Date): Promise<string> {
  const bills = await prisma.bill.findMany({
    where: { businessId, date: { gte: startDate, lte: endDate } },
    include: { location: { select: { name: true } }, operator: { select: { name: true } } },
    orderBy: { date: 'asc' },
  });

  const header = 'Bill Number,Date,Location,Operator,Subtotal,CGST,SGST,Total,Payment Mode,Cash,UPI,Source\n';
  const rows = bills.map((b) =>
    `${b.billNumber},${b.date.toISOString().split('T')[0]},${b.location.name},${b.operator.name},${b.subtotal},${b.cgstAmount},${b.sgstAmount},${b.total},${b.paymentMode},${b.cashAmount},${b.upiAmount},${b.orderSource}`,
  );

  return header + rows.join('\n');
}
