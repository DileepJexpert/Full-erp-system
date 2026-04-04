import { prisma } from '../../lib/prisma.js';
import { cacheGet, cacheSet } from '../../lib/redis.js';

interface DashboardOverview {
  todayRevenue: number;
  todayBillCount: number;
  activeLocations: number;
  pendingDispatches: number;
  unreconciledDispatches: number;
  todayExpenses: number;
  unreadAlerts: number;
  cashCollectedToday: number;
  cashShortageToday: number;
  totalLossThisMonth: number;
}

export async function getOverview(businessId: string): Promise<DashboardOverview> {
  const cacheKey = `dashboard:${businessId}:overview`;
  const cached = await cacheGet<DashboardOverview>(cacheKey);
  if (cached) return cached;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

  const [
    todayBills,
    activeLocations,
    pendingDispatches,
    unreconciledDispatches,
    todayExpensesAgg,
    unreadAlerts,
    todayCash,
    monthLoss,
  ] = await Promise.all([
    prisma.bill.aggregate({
      where: { businessId, date: today },
      _sum: { total: true },
      _count: true,
    }),
    prisma.location.count({ where: { businessId, isActive: true } }),
    prisma.dispatch.count({ where: { businessId, status: 'PENDING' } }),
    prisma.dispatch.count({ where: { businessId, status: 'CONFIRMED' } }),
    prisma.expense.aggregate({
      where: { businessId, date: today },
      _sum: { amount: true },
    }),
    prisma.alert.count({ where: { businessId, status: 'UNREAD' } }),
    prisma.cashCollection.aggregate({
      where: { businessId, date: today },
      _sum: { actualCollected: true, shortage: true },
    }),
    prisma.reconciliation.aggregate({
      where: { businessId, date: { gte: monthStart } },
      _sum: { totalLoss: true },
    }),
  ]);

  const overview: DashboardOverview = {
    todayRevenue: todayBills._sum.total ?? 0,
    todayBillCount: todayBills._count,
    activeLocations,
    pendingDispatches,
    unreconciledDispatches,
    todayExpenses: todayExpensesAgg._sum.amount ?? 0,
    unreadAlerts,
    cashCollectedToday: todayCash._sum.actualCollected ?? 0,
    cashShortageToday: todayCash._sum.shortage ?? 0,
    totalLossThisMonth: monthLoss._sum.totalLoss ?? 0,
  };

  await cacheSet(cacheKey, overview, 120); // 2 min cache
  return overview;
}

export async function getLocationStats(businessId: string, startDate: Date, endDate: Date) {
  const locations = await prisma.location.findMany({
    where: { businessId, isActive: true },
    select: { id: true, name: true, type: true },
  });

  const stats = await Promise.all(
    locations.map(async (loc) => {
      const [revenue, reconLoss, billCount] = await Promise.all([
        prisma.bill.aggregate({
          where: { businessId, locationId: loc.id, date: { gte: startDate, lte: endDate } },
          _sum: { total: true },
        }),
        prisma.reconciliation.aggregate({
          where: { businessId, locationId: loc.id, date: { gte: startDate, lte: endDate } },
          _sum: { totalLoss: true },
        }),
        prisma.bill.count({
          where: { businessId, locationId: loc.id, date: { gte: startDate, lte: endDate } },
        }),
      ]);

      return {
        locationId: loc.id,
        locationName: loc.name,
        locationType: loc.type,
        totalRevenue: revenue._sum.total ?? 0,
        totalLoss: reconLoss._sum.totalLoss ?? 0,
        billCount,
      };
    }),
  );

  return stats.sort((a, b) => b.totalRevenue - a.totalRevenue);
}
