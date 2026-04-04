import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

interface TriggerConfig {
  locationId?: string;
  threshold?: number;
  thresholdHour?: number;
  itemId?: string;
}

interface ActionConfig {
  message?: string;
  severity?: string;
  title?: string;
  recipients?: string[];
}

interface EvaluationResult {
  triggered: boolean;
  reason: string;
  currentValue?: number;
  threshold?: number;
}

/**
 * Evaluate a single automation rule against live data.
 * Returns whether the rule's condition is met.
 */
export async function evaluateRule(
  businessId: string,
  ruleId: string,
): Promise<EvaluationResult> {
  const rule = await prisma.automationRule.findFirst({
    where: { id: ruleId, businessId },
  });

  if (!rule) throw new NotFoundError('AutomationRule', ruleId);

  const config = rule.triggerConfig as TriggerConfig;
  const threshold = config.threshold ?? 0;

  switch (rule.trigger) {
    case 'REVENUE_BELOW': {
      const todayStart = startOfDay(new Date());
      const todayEnd = endOfDay(new Date());
      const agg = await prisma.bill.aggregate({
        where: {
          businessId,
          ...(config.locationId ? { locationId: config.locationId } : {}),
          date: { gte: todayStart, lte: todayEnd },
        },
        _sum: { total: true },
      });
      const revenue = agg._sum.total ?? 0;
      return {
        triggered: revenue < threshold,
        reason: `Today's revenue (${revenue}) ${revenue < threshold ? 'is below' : 'meets'} threshold (${threshold})`,
        currentValue: revenue,
        threshold,
      };
    }

    case 'REVENUE_ABOVE': {
      const todayStart = startOfDay(new Date());
      const todayEnd = endOfDay(new Date());
      const agg = await prisma.bill.aggregate({
        where: {
          businessId,
          ...(config.locationId ? { locationId: config.locationId } : {}),
          date: { gte: todayStart, lte: todayEnd },
        },
        _sum: { total: true },
      });
      const revenue = agg._sum.total ?? 0;
      return {
        triggered: revenue > threshold,
        reason: `Today's revenue (${revenue}) ${revenue > threshold ? 'exceeds' : 'is within'} threshold (${threshold})`,
        currentValue: revenue,
        threshold,
      };
    }

    case 'STOCK_BELOW': {
      if (config.itemId) {
        const item = await prisma.item.findFirst({
          where: { id: config.itemId, businessId },
        });
        if (!item) return { triggered: false, reason: `Item ${config.itemId} not found` };
        return {
          triggered: item.centralStock < threshold,
          reason: `Item "${item.name}" stock (${item.centralStock}) ${item.centralStock < threshold ? 'is below' : 'meets'} threshold (${threshold})`,
          currentValue: item.centralStock,
          threshold,
        };
      }
      // Check all items below threshold
      const lowItems = await prisma.item.findMany({
        where: { businessId, centralStock: { lt: threshold }, isActive: true },
        select: { id: true, name: true, centralStock: true },
      });
      return {
        triggered: lowItems.length > 0,
        reason: lowItems.length > 0
          ? `${lowItems.length} item(s) below stock threshold: ${lowItems.map(i => i.name).join(', ')}`
          : `All items above stock threshold (${threshold})`,
        currentValue: lowItems.length,
        threshold,
      };
    }

    case 'LATE_RECONCILIATION': {
      const thresholdHour = config.thresholdHour ?? 22; // default 10 PM
      const now = new Date();
      const currentHour = now.getHours();

      if (currentHour < thresholdHour) {
        return { triggered: false, reason: `Current hour (${currentHour}) is before threshold (${thresholdHour})` };
      }

      const todayStart = startOfDay(now);
      const todayEnd = endOfDay(now);

      // Find dispatches today that have no reconciliation
      const unreconciledDispatches = await prisma.dispatch.findMany({
        where: {
          businessId,
          date: { gte: todayStart, lte: todayEnd },
          ...(config.locationId ? { locationId: config.locationId } : {}),
          reconciliation: null,
        },
        select: { id: true, locationId: true },
      });

      return {
        triggered: unreconciledDispatches.length > 0,
        reason: unreconciledDispatches.length > 0
          ? `${unreconciledDispatches.length} dispatch(es) unreconciled after ${thresholdHour}:00`
          : 'All dispatches reconciled',
        currentValue: unreconciledDispatches.length,
        threshold: thresholdHour,
      };
    }

    case 'EXPENSE_ABOVE': {
      const todayStart = startOfDay(new Date());
      const todayEnd = endOfDay(new Date());
      const agg = await prisma.expense.aggregate({
        where: {
          businessId,
          ...(config.locationId ? { locationId: config.locationId } : {}),
          date: { gte: todayStart, lte: todayEnd },
        },
        _sum: { amount: true },
      });
      const expenses = agg._sum.amount ?? 0;
      return {
        triggered: expenses > threshold,
        reason: `Today's expenses (${expenses}) ${expenses > threshold ? 'exceed' : 'are within'} threshold (${threshold})`,
        currentValue: expenses,
        threshold,
      };
    }

    case 'WASTAGE_ABOVE': {
      // Check recent reconciliation wastage percentage
      const recentRecons = await prisma.reconciliation.findMany({
        where: {
          businessId,
          ...(config.locationId ? { locationId: config.locationId } : {}),
        },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: { totalLoss: true },
      });

      if (recentRecons.length === 0) {
        return { triggered: false, reason: 'No recent reconciliations found' };
      }

      const avgLoss = recentRecons.reduce((sum, r) => sum + r.totalLoss, 0) / recentRecons.length;
      return {
        triggered: avgLoss > threshold,
        reason: `Average recent wastage loss (${avgLoss.toFixed(2)}) ${avgLoss > threshold ? 'exceeds' : 'is within'} threshold (${threshold})`,
        currentValue: avgLoss,
        threshold,
      };
    }

    case 'CASH_SHORTAGE': {
      // Count cash shortages this week
      const weekStart = getMonday(new Date());
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 6);
      weekEnd.setHours(23, 59, 59);

      const shortageCount = await prisma.cashCollection.count({
        where: {
          businessId,
          ...(config.locationId ? { locationId: config.locationId } : {}),
          date: { gte: weekStart, lte: weekEnd },
          shortage: { gt: 0 },
        },
      });

      return {
        triggered: shortageCount >= threshold,
        reason: `Cash shortages this week (${shortageCount}) ${shortageCount >= threshold ? 'meets/exceeds' : 'is below'} threshold (${threshold})`,
        currentValue: shortageCount,
        threshold,
      };
    }

    case 'LATE_CHECKIN': {
      // Placeholder: check today's attendance for late check-ins
      return { triggered: false, reason: 'LATE_CHECKIN evaluation not yet implemented' };
    }

    case 'BILL_AMOUNT_ABOVE': {
      const todayStart = startOfDay(new Date());
      const todayEnd = endOfDay(new Date());
      const largeBills = await prisma.bill.findMany({
        where: {
          businessId,
          ...(config.locationId ? { locationId: config.locationId } : {}),
          date: { gte: todayStart, lte: todayEnd },
          total: { gt: threshold },
        },
        select: { id: true, total: true },
      });
      return {
        triggered: largeBills.length > 0,
        reason: largeBills.length > 0
          ? `${largeBills.length} bill(s) above threshold (${threshold})`
          : `No bills above threshold (${threshold})`,
        currentValue: largeBills.length,
        threshold,
      };
    }

    case 'CUSTOM': {
      return { triggered: false, reason: 'Custom trigger requires manual evaluation' };
    }

    default:
      return { triggered: false, reason: `Unknown trigger type: ${rule.trigger}` };
  }
}

/**
 * Execute a rule: evaluate condition, respect cooldown, execute action if triggered.
 * Returns the evaluation result + whether the action was executed.
 */
export async function executeRule(
  businessId: string,
  ruleId: string,
  dryRun = false,
): Promise<EvaluationResult & { actionExecuted: boolean }> {
  const rule = await prisma.automationRule.findFirst({
    where: { id: ruleId, businessId },
  });

  if (!rule) throw new NotFoundError('AutomationRule', ruleId);
  if (!rule.isActive) throw new BadRequestError('Rule is not active');

  // Check cooldown
  if (rule.lastTriggeredAt) {
    const elapsed = Date.now() - rule.lastTriggeredAt.getTime();
    if (elapsed < COOLDOWN_MS) {
      return {
        triggered: false,
        reason: `Rule in cooldown. ${Math.ceil((COOLDOWN_MS - elapsed) / 60000)} minutes remaining.`,
        actionExecuted: false,
      };
    }
  }

  const evaluation = await evaluateRule(businessId, ruleId);

  if (!evaluation.triggered || dryRun) {
    return { ...evaluation, actionExecuted: false };
  }

  // Execute the action
  const actionConfig = rule.actionConfig as ActionConfig;

  switch (rule.action) {
    case 'CREATE_ALERT': {
      await prisma.alert.create({
        data: {
          type: 'PATTERN_DETECTED',
          severity: (actionConfig.severity as any) ?? 'WARNING',
          title: actionConfig.title ?? `Automation: ${rule.name}`,
          description: actionConfig.message ?? evaluation.reason,
          businessId,
          ...(((rule.triggerConfig as TriggerConfig).locationId)
            ? { locationId: (rule.triggerConfig as TriggerConfig).locationId }
            : {}),
        },
      });
      break;
    }

    case 'SEND_PUSH': {
      // Placeholder: log push notification
      console.log(`[Automation] SEND_PUSH for rule "${rule.name}": ${actionConfig.message ?? evaluation.reason}`);
      break;
    }

    case 'SEND_WHATSAPP': {
      // Placeholder: log WhatsApp message
      console.log(
        `[Automation] SEND_WHATSAPP for rule "${rule.name}" to ${(actionConfig.recipients ?? []).join(', ')}: ${actionConfig.message ?? evaluation.reason}`,
      );
      break;
    }

    case 'BLOCK_EXPENSE': {
      console.log(`[Automation] BLOCK_EXPENSE triggered by rule "${rule.name}"`);
      break;
    }

    case 'AUTO_REMINDER': {
      console.log(`[Automation] AUTO_REMINDER for rule "${rule.name}": ${actionConfig.message ?? evaluation.reason}`);
      break;
    }
  }

  // Update trigger stats
  await prisma.automationRule.update({
    where: { id: ruleId },
    data: {
      timesTriggered: { increment: 1 },
      lastTriggeredAt: new Date(),
    },
  });

  return { ...evaluation, actionExecuted: true };
}

// ── Date helpers ──

function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

function getMonday(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  d.setDate(diff);
  d.setHours(0, 0, 0, 0);
  return d;
}
