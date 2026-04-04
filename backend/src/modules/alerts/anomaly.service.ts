import { prisma } from '../../lib/prisma.js';
import { createAlert } from './alerts.service.js';
import {
  ANOMALY_WASTAGE_MULTIPLIER,
  ANOMALY_BILLING_MISMATCH_THRESHOLD,
  ANOMALY_REVENUE_DROP_THRESHOLD,
  ANOMALY_CASH_SHORTAGE_WEEKLY_THRESHOLD,
  ANOMALY_LATE_RECON_HOUR,
  ANOMALY_LATE_RECON_PERCENTAGE,
} from '../../config/constants.js';

export async function runAnomalyScan(businessId: string): Promise<number> {
  let alertsCreated = 0;
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  // 1. WASTAGE_HIGH: operator avg wastage > fleet avg × 1.2 over 7 days
  alertsCreated += await detectHighWastage(businessId, sevenDaysAgo);

  // 2. BILLING_MISMATCH: recon 'sold' differs from billed qty by >15%
  alertsCreated += await detectBillingMismatch(businessId, sevenDaysAgo);

  // 3. REVENUE_DROP: location revenue drops >30% vs same day last week
  alertsCreated += await detectRevenueDrop(businessId, now);

  // 4. CASH_SHORTAGE: >3 shortages in a week at same location
  alertsCreated += await detectCashShortage(businessId, sevenDaysAgo);

  // 5. LATE_RECON: operator submits recon after 10 PM >50% of time
  alertsCreated += await detectLateRecon(businessId, sevenDaysAgo);

  // 6. PATTERN_DETECTED: wastage/shortage clusters on specific day of week
  alertsCreated += await detectPatterns(businessId, sevenDaysAgo);

  return alertsCreated;
}

async function detectHighWastage(businessId: string, since: Date): Promise<number> {
  let count = 0;
  const recons = await prisma.reconciliation.findMany({
    where: { businessId, date: { gte: since } },
    include: { items: true, operator: true, location: true },
  });

  if (recons.length === 0) return 0;

  // Calculate fleet average wastage rate
  let totalDispatched = 0;
  let totalWasted = 0;
  for (const r of recons) {
    for (const item of r.items) {
      totalDispatched += item.dispatched;
      totalWasted += item.wasted;
    }
  }
  const fleetAvgWastageRate = totalDispatched > 0 ? totalWasted / totalDispatched : 0;

  // Per-operator wastage
  const operatorWastage = new Map<string, { dispatched: number; wasted: number; name: string; locationId: string }>();
  for (const r of recons) {
    const existing = operatorWastage.get(r.operatorId) ?? { dispatched: 0, wasted: 0, name: r.operator.name, locationId: r.locationId };
    for (const item of r.items) {
      existing.dispatched += item.dispatched;
      existing.wasted += item.wasted;
    }
    operatorWastage.set(r.operatorId, existing);
  }

  for (const [operatorId, data] of operatorWastage) {
    const rate = data.dispatched > 0 ? data.wasted / data.dispatched : 0;
    if (rate > fleetAvgWastageRate * ANOMALY_WASTAGE_MULTIPLIER) {
      await createAlert(businessId, {
        type: 'WASTAGE_HIGH',
        severity: 'WARNING',
        title: `High wastage: ${data.name}`,
        description: `Operator wastage rate (${(rate * 100).toFixed(1)}%) exceeds fleet average (${(fleetAvgWastageRate * 100).toFixed(1)}%) by more than 20%`,
        operatorId,
        locationId: data.locationId,
        data: { operatorRate: rate, fleetRate: fleetAvgWastageRate },
      });
      count++;
    }
  }
  return count;
}

async function detectBillingMismatch(businessId: string, since: Date): Promise<number> {
  let count = 0;
  const recons = await prisma.reconciliation.findMany({
    where: { businessId, date: { gte: since } },
    include: { items: { include: { item: true } }, location: true },
  });

  for (const recon of recons) {
    const bills = await prisma.bill.findMany({
      where: { businessId, locationId: recon.locationId, date: recon.date },
      include: { items: true },
    });

    // Sum billed quantities per item
    const billedQty = new Map<string, number>();
    for (const bill of bills) {
      for (const bi of bill.items) {
        billedQty.set(bi.itemId, (billedQty.get(bi.itemId) ?? 0) + bi.quantity);
      }
    }

    for (const ri of recon.items) {
      const billed = billedQty.get(ri.itemId) ?? 0;
      if (ri.sold > 0 && Math.abs(ri.sold - billed) / ri.sold > ANOMALY_BILLING_MISMATCH_THRESHOLD) {
        await createAlert(businessId, {
          type: 'BILLING_MISMATCH',
          severity: 'CRITICAL',
          title: `Billing mismatch: ${ri.item.name}`,
          description: `Reconciliation reports ${ri.sold} sold but only ${billed} billed at ${recon.location?.id}`,
          locationId: recon.locationId,
          data: { itemId: ri.itemId, reconSold: ri.sold, billedQty: billed, date: recon.date },
        });
        count++;
      }
    }
  }
  return count;
}

async function detectRevenueDrop(businessId: string, now: Date): Promise<number> {
  let count = 0;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const lastWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

  const locations = await prisma.location.findMany({ where: { businessId, isActive: true } });

  for (const loc of locations) {
    const [todayBills, lastWeekBills] = await Promise.all([
      prisma.bill.aggregate({ where: { businessId, locationId: loc.id, date: today }, _sum: { total: true } }),
      prisma.bill.aggregate({ where: { businessId, locationId: loc.id, date: lastWeek }, _sum: { total: true } }),
    ]);

    const todayRevenue = todayBills._sum.total ?? 0;
    const lastWeekRevenue = lastWeekBills._sum.total ?? 0;

    if (lastWeekRevenue > 0 && (lastWeekRevenue - todayRevenue) / lastWeekRevenue > ANOMALY_REVENUE_DROP_THRESHOLD) {
      await createAlert(businessId, {
        type: 'REVENUE_DROP',
        severity: 'WARNING',
        title: `Revenue drop: ${loc.name}`,
        description: `Revenue dropped ${((1 - todayRevenue / lastWeekRevenue) * 100).toFixed(0)}% vs same day last week`,
        locationId: loc.id,
        data: { todayRevenue, lastWeekRevenue },
      });
      count++;
    }
  }
  return count;
}

async function detectCashShortage(businessId: string, since: Date): Promise<number> {
  let count = 0;
  const collections = await prisma.cashCollection.findMany({
    where: { businessId, date: { gte: since }, shortage: { gt: 0 } },
    include: { location: true },
  });

  const locationShortages = new Map<string, { count: number; name: string }>();
  for (const c of collections) {
    const existing = locationShortages.get(c.locationId) ?? { count: 0, name: c.location.name };
    existing.count++;
    locationShortages.set(c.locationId, existing);
  }

  for (const [locationId, data] of locationShortages) {
    if (data.count > ANOMALY_CASH_SHORTAGE_WEEKLY_THRESHOLD) {
      await createAlert(businessId, {
        type: 'CASH_SHORTAGE',
        severity: 'CRITICAL',
        title: `Repeated cash shortages: ${data.name}`,
        description: `${data.count} cash shortages in the past week`,
        locationId,
        data: { shortageCount: data.count },
      });
      count++;
    }
  }
  return count;
}

async function detectLateRecon(businessId: string, since: Date): Promise<number> {
  let count = 0;
  const recons = await prisma.reconciliation.findMany({
    where: { businessId, date: { gte: since } },
    include: { operator: true },
  });

  const operatorRecons = new Map<string, { total: number; late: number; name: string }>();
  for (const r of recons) {
    const existing = operatorRecons.get(r.operatorId) ?? { total: 0, late: 0, name: r.operator.name };
    existing.total++;
    if (r.createdAt.getHours() >= ANOMALY_LATE_RECON_HOUR) {
      existing.late++;
    }
    operatorRecons.set(r.operatorId, existing);
  }

  for (const [operatorId, data] of operatorRecons) {
    if (data.total >= 3 && data.late / data.total > ANOMALY_LATE_RECON_PERCENTAGE) {
      await createAlert(businessId, {
        type: 'LATE_RECON',
        severity: 'INFO',
        title: `Late reconciliation: ${data.name}`,
        description: `${data.late}/${data.total} reconciliations submitted after 10 PM`,
        operatorId,
        data: { lateCount: data.late, totalCount: data.total },
      });
      count++;
    }
  }
  return count;
}

async function detectPatterns(businessId: string, since: Date): Promise<number> {
  let count = 0;
  // Check for day-of-week clustering in wastage
  const recons = await prisma.reconciliation.findMany({
    where: { businessId, date: { gte: since }, totalLoss: { gt: 0 } },
    include: { operator: true },
  });

  const dayCount = new Map<number, number>();
  for (const r of recons) {
    const day = r.date.getDay();
    dayCount.set(day, (dayCount.get(day) ?? 0) + 1);
  }

  const totalRecons = recons.length;
  if (totalRecons >= 5) {
    for (const [day, count_] of dayCount) {
      // If more than 40% of losses cluster on one day
      if (count_ / totalRecons > 0.4) {
        const dayName = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][day];
        await createAlert(businessId, {
          type: 'PATTERN_DETECTED',
          severity: 'WARNING',
          title: `Loss pattern detected: ${dayName}`,
          description: `${count_}/${totalRecons} losses occurred on ${dayName}s — possible pattern`,
          data: { dayOfWeek: day, dayName, occurrences: count_, total: totalRecons },
        });
        count++;
      }
    }
  }
  return count;
}
