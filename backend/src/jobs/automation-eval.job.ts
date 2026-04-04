import { prisma } from '../lib/prisma.js';

const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour cooldown per rule

/**
 * Every 15 min: evaluate all active AutomationRules. Cooldown: 1 hour per rule.
 */
export async function runAutomationEvalJob(): Promise<void> {
  console.log('[JOB] automation-eval: starting...');

  const now = new Date();
  const cooldownThreshold = new Date(now.getTime() - COOLDOWN_MS);

  // Find active rules that haven't triggered within the cooldown period
  const rules = await prisma.automationRule.findMany({
    where: {
      isActive: true,
      OR: [
        { lastTriggeredAt: null },
        { lastTriggeredAt: { lt: cooldownThreshold } },
      ],
    },
  });

  let triggeredCount = 0;

  for (const rule of rules) {
    try {
      const shouldTrigger = await evaluateRule(rule);

      if (shouldTrigger) {
        await executeAction(rule);

        await prisma.automationRule.update({
          where: { id: rule.id },
          data: {
            lastTriggeredAt: now,
            timesTriggered: { increment: 1 },
          },
        });

        triggeredCount++;
        console.log(`[JOB] automation-eval: triggered rule "${rule.name}" (${rule.trigger})`);
      }
    } catch (err) {
      console.error(`[JOB] automation-eval: failed to evaluate rule "${rule.name}" (${rule.id}):`, err);
    }
  }

  console.log(`[JOB] automation-eval: completed. ${triggeredCount}/${rules.length} rules triggered.`);
}

async function evaluateRule(rule: {
  id: string;
  trigger: string;
  triggerConfig: unknown;
  businessId: string;
}): Promise<boolean> {
  const config = rule.triggerConfig as Record<string, unknown>;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayEnd = new Date(today);
  todayEnd.setHours(23, 59, 59, 999);

  switch (rule.trigger) {
    case 'REVENUE_BELOW': {
      const threshold = config.threshold as number;
      const locationId = config.locationId as string | undefined;
      const where: Record<string, unknown> = {
        businessId: rule.businessId,
        date: { gte: today, lte: todayEnd },
      };
      if (locationId) where.locationId = locationId;
      const agg = await prisma.bill.aggregate({ where, _sum: { total: true } });
      return (agg._sum.total ?? 0) < threshold;
    }

    case 'REVENUE_ABOVE': {
      const threshold = config.threshold as number;
      const locationId = config.locationId as string | undefined;
      const where: Record<string, unknown> = {
        businessId: rule.businessId,
        date: { gte: today, lte: todayEnd },
      };
      if (locationId) where.locationId = locationId;
      const agg = await prisma.bill.aggregate({ where, _sum: { total: true } });
      return (agg._sum.total ?? 0) > threshold;
    }

    case 'EXPENSE_ABOVE': {
      const threshold = config.threshold as number;
      const locationId = config.locationId as string | undefined;
      const where: Record<string, unknown> = {
        businessId: rule.businessId,
        date: { gte: today, lte: todayEnd },
      };
      if (locationId) where.locationId = locationId;
      const agg = await prisma.expense.aggregate({ where, _sum: { amount: true } });
      return (agg._sum.amount ?? 0) > threshold;
    }

    case 'STOCK_BELOW': {
      const threshold = config.threshold as number;
      const itemId = config.itemId as string | undefined;
      const where: Record<string, unknown> = {
        businessId: rule.businessId,
        isActive: true,
        centralStock: { lt: threshold },
      };
      if (itemId) where.id = itemId;
      const count = await prisma.item.count({ where });
      return count > 0;
    }

    case 'WASTAGE_ABOVE': {
      const threshold = config.threshold as number;
      const agg = await prisma.reconciliation.aggregate({
        where: {
          businessId: rule.businessId,
          date: { gte: today, lte: todayEnd },
        },
        _sum: { totalLoss: true },
      });
      return (agg._sum.totalLoss ?? 0) > threshold;
    }

    case 'CASH_SHORTAGE': {
      const threshold = config.threshold as number;
      // Check if any cash collection has a shortage above threshold
      const collections = await prisma.cashCollection.findMany({
        where: {
          businessId: rule.businessId,
          date: { gte: today, lte: todayEnd },
        },
      });
      // A shortage is when expected > actual (we check via related bills vs collected)
      for (const c of collections) {
        const bills = await prisma.bill.aggregate({
          where: {
            businessId: rule.businessId,
            locationId: c.locationId,
            date: { gte: today, lte: todayEnd },
            paymentMode: { in: ['CASH', 'MIXED'] },
          },
          _sum: { cashAmount: true },
        });
        const expectedCash = bills._sum.cashAmount ?? 0;
        const actualCash = c.actualCollected;
        if (expectedCash - actualCash > threshold) return true;
      }
      return false;
    }

    case 'LATE_RECONCILIATION': {
      const hoursThreshold = (config.hours as number) ?? 20; // default 8pm
      const currentHour = new Date().getHours();
      if (currentHour < hoursThreshold) return false;

      // Check locations without reconciliation today
      const locations = await prisma.location.findMany({
        where: { businessId: rule.businessId, isActive: true },
        select: { id: true },
      });
      const reconciled = await prisma.reconciliation.findMany({
        where: {
          businessId: rule.businessId,
          date: { gte: today, lte: todayEnd },
        },
        select: { locationId: true },
      });
      const reconSet = new Set(reconciled.map((r) => r.locationId));
      return locations.some((l) => !reconSet.has(l.id));
    }

    case 'LATE_CHECKIN': {
      const lateMinutes = (config.lateMinutes as number) ?? 30;
      const shifts = await prisma.shiftSchedule.findMany({
        where: {
          businessId: rule.businessId,
          date: { gte: today, lte: todayEnd },
        },
      });
      for (const shift of shifts) {
        const [hours, minutes] = shift.shiftStart.split(':').map(Number);
        const shiftStartTime = new Date(today);
        shiftStartTime.setHours(hours, minutes, 0, 0);
        const lateThreshold = new Date(shiftStartTime.getTime() + lateMinutes * 60 * 1000);

        if (new Date() < lateThreshold) continue; // Not late yet

        const attendance = await prisma.attendance.findFirst({
          where: {
            businessId: rule.businessId,
            operatorId: shift.userId,
            date: { gte: today, lte: todayEnd },
          },
        });
        if (!attendance) return true; // No check-in at all
        if (attendance.checkInTime > lateThreshold) return true; // Checked in late
      }
      return false;
    }

    case 'BILL_AMOUNT_ABOVE': {
      const threshold = config.threshold as number;
      const count = await prisma.bill.count({
        where: {
          businessId: rule.businessId,
          date: { gte: today, lte: todayEnd },
          total: { gt: threshold },
        },
      });
      return count > 0;
    }

    case 'CUSTOM': {
      // Custom rules are not auto-evaluated; they need external triggers
      return false;
    }

    default:
      console.warn(`[JOB] automation-eval: unknown trigger type "${rule.trigger}"`);
      return false;
  }
}

async function executeAction(rule: {
  id: string;
  name: string;
  action: string;
  actionConfig: unknown;
  businessId: string;
}): Promise<void> {
  const config = rule.actionConfig as Record<string, unknown>;

  switch (rule.action) {
    case 'CREATE_ALERT': {
      await prisma.alert.create({
        data: {
          type: (config.alertType as string) ?? 'PATTERN_DETECTED',
          severity: (config.severity as string) ?? 'WARNING',
          title: config.title as string ?? `Automation: ${rule.name}`,
          description: config.description as string ?? `Rule "${rule.name}" was triggered.`,
          businessId: rule.businessId,
          locationId: config.locationId as string | undefined,
          data: { ruleId: rule.id, ruleName: rule.name },
        } as any,
      });
      break;
    }

    case 'SEND_WHATSAPP': {
      // Placeholder for WhatsApp delivery
      const phone = config.phone as string;
      const message = config.message as string ?? `Alert: Rule "${rule.name}" triggered.`;
      console.log(`[JOB] automation-eval: SEND_WHATSAPP to ${phone}: ${message}`);
      break;
    }

    case 'SEND_PUSH': {
      // Placeholder for push notification
      const title = config.title as string ?? rule.name;
      const body = config.body as string ?? `Rule "${rule.name}" triggered.`;
      console.log(`[JOB] automation-eval: SEND_PUSH - ${title}: ${body}`);
      break;
    }

    case 'BLOCK_EXPENSE': {
      // Placeholder - in practice this would set a flag on the location/business
      console.log(`[JOB] automation-eval: BLOCK_EXPENSE triggered for business ${rule.businessId}`);
      break;
    }

    case 'AUTO_REMINDER': {
      const message = config.message as string ?? `Reminder from rule "${rule.name}"`;
      console.log(`[JOB] automation-eval: AUTO_REMINDER for business ${rule.businessId}: ${message}`);
      break;
    }

    default:
      console.warn(`[JOB] automation-eval: unknown action "${rule.action}"`);
  }
}
