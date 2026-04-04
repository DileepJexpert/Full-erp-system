import { prisma } from '../../lib/prisma.js';
import { claude } from '../../lib/claude.js';

interface WeeklyMetrics {
  revenue: { total: number; byLocation: Array<{ name: string; total: number }> };
  bills: { total: number; avgPerDay: number };
  wastage: { total: number; byOperator: Array<{ name: string; loss: number }> };
  expenses: { total: number; categories: Array<{ category: string; amount: number }> };
  stockAlerts: number;
  attendance: { avgRate: number };
  topItems: Array<{ name: string; qty: number; revenue: number }>;
}

/**
 * Gather the past week's data across all key metrics for a business.
 */
async function gatherWeeklyMetrics(businessId: string): Promise<WeeklyMetrics> {
  const now = new Date();
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);

  // Revenue & Bills
  const bills = await prisma.bill.findMany({
    where: { businessId, date: { gte: weekAgo, lte: now } },
    include: { location: { select: { name: true } } },
  });

  const totalRevenue = bills.reduce((s, b) => s + (b.total as number), 0);
  const revenueByLocation = new Map<string, { name: string; total: number }>();
  for (const bill of bills) {
    const locName = (bill as any).location?.name ?? bill.locationId;
    const existing = revenueByLocation.get(bill.locationId) ?? { name: locName, total: 0 };
    existing.total += bill.total as number;
    revenueByLocation.set(bill.locationId, existing);
  }

  // Wastage
  const recons = await prisma.reconciliation.findMany({
    where: { businessId, date: { gte: weekAgo, lte: now } },
    select: { operatorId: true, totalLoss: true },
  });
  const totalWastage = recons.reduce((s, r) => s + (r.totalLoss as number), 0);

  const wastageByOp = new Map<string, number>();
  for (const r of recons) {
    wastageByOp.set(r.operatorId, (wastageByOp.get(r.operatorId) ?? 0) + (r.totalLoss as number));
  }

  const operatorIds = Array.from(wastageByOp.keys());
  const operators = await prisma.user.findMany({
    where: { id: { in: operatorIds } },
    select: { id: true, name: true },
  });
  const opNameMap = new Map(operators.map((o) => [o.id, o.name]));

  // Expenses
  const expenses = await prisma.expense.findMany({
    where: { businessId, date: { gte: weekAgo, lte: now } },
  });
  const totalExpenses = expenses.reduce((s, e) => s + (e.amount as number), 0);
  const expByCategory = new Map<string, number>();
  for (const e of expenses) {
    const cat = (e as any).category ?? 'Other';
    expByCategory.set(cat, (expByCategory.get(cat) ?? 0) + (e.amount as number));
  }

  // Stock alerts
  // Count items where stock is at or below minimum level
  const allItems = await prisma.item.findMany({
    where: { businessId },
    select: { centralStock: true, minStockLevel: true },
  });
  const stockAlerts = allItems.filter(
    (i) => (i.centralStock ?? 0) <= (i.minStockLevel ?? 0),
  ).length;

  // Attendance rate
  const staffCount = await prisma.user.count({
    where: { businessId, role: { in: ['STAFF', 'MANAGER'] } },
  });
  const attendanceCount = await prisma.attendance.count({
    where: { businessId, date: { gte: weekAgo, lte: now } },
  });
  const expectedAttendance = staffCount * 7;
  const attendanceRate =
    expectedAttendance > 0
      ? Math.round((attendanceCount / expectedAttendance) * 100)
      : 0;

  // Top selling items
  const billItems = await prisma.billItem.findMany({
    where: { bill: { businessId, date: { gte: weekAgo, lte: now } } },
    include: { item: { select: { name: true } } },
  });

  const itemAgg = new Map<string, { name: string; qty: number; revenue: number }>();
  for (const bi of billItems) {
    const existing = itemAgg.get(bi.itemId) ?? {
      name: (bi as any).item?.name ?? bi.itemId,
      qty: 0,
      revenue: 0,
    };
    existing.qty += bi.quantity;
    existing.revenue += bi.lineTotal as number;
    itemAgg.set(bi.itemId, existing);
  }

  const topItems = Array.from(itemAgg.values())
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 5);

  return {
    revenue: {
      total: Math.round(totalRevenue),
      byLocation: Array.from(revenueByLocation.values()).map((v) => ({
        name: v.name,
        total: Math.round(v.total),
      })),
    },
    bills: {
      total: bills.length,
      avgPerDay: Math.round((bills.length / 7) * 10) / 10,
    },
    wastage: {
      total: Math.round(totalWastage),
      byOperator: Array.from(wastageByOp.entries()).map(([id, loss]) => ({
        name: opNameMap.get(id) ?? id,
        loss: Math.round(loss),
      })),
    },
    expenses: {
      total: Math.round(totalExpenses),
      categories: Array.from(expByCategory.entries()).map(([category, amount]) => ({
        category,
        amount: Math.round(amount),
      })),
    },
    stockAlerts: typeof stockAlerts === 'number' ? stockAlerts : 0,
    attendance: { avgRate: attendanceRate },
    topItems: topItems.map((i) => ({
      name: i.name,
      qty: i.qty,
      revenue: Math.round(i.revenue),
    })),
  };
}

/**
 * Generate 3-5 actionable insight cards for a business based on the past week's data.
 * Meant to be run weekly (e.g., via cron job).
 */
export async function generateWeeklyInsights(businessId: string): Promise<void> {
  const metrics = await gatherWeeklyMetrics(businessId);

  const prompt = [
    `Analyze the following weekly business metrics and generate 3-5 insight cards.`,
    `Each insight should be actionable and specific.`,
    ``,
    `Weekly Metrics:`,
    JSON.stringify(metrics, null, 2),
    ``,
    `Respond in exactly this JSON format (array of objects):`,
    `[`,
    `  {`,
    `    "title": "short headline (max 60 chars)",`,
    `    "description": "detailed insight with specific numbers and action items (max 300 chars)",`,
    `    "category": "one of: revenue, wastage, expenses, stock, staff, growth",`,
    `    "actionable": true/false`,
    `  }`,
    `]`,
    ``,
    `Focus on:`,
    `- Revenue trends and location comparisons`,
    `- Wastage patterns and operator accountability`,
    `- Stock replenishment needs`,
    `- Cost optimization opportunities`,
    `- Staff performance insights`,
    ``,
    `Use Hinglish (Hindi-English mix) for a natural feel. Be direct and specific.`,
  ].join('\n');

  try {
    const { text, tokensUsed } = await claude.query(prompt, {
      maxTokens: 2048,
      system: 'You are a business analytics engine. Return only valid JSON arrays, nothing else.',
    });

    // Parse the response
    const jsonMatch = text.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      console.error('[InsightGenerator] Claude did not return valid JSON array');
      return;
    }

    const insights = JSON.parse(jsonMatch[0]) as Array<{
      title: string;
      description: string;
      category: string;
      actionable: boolean;
    }>;

    // Store insight cards
    for (const insight of insights) {
      await prisma.insightCard.create({
        data: {
          title: insight.title.slice(0, 100),
          description: insight.description.slice(0, 500),
          category: insight.category,
          actionable: insight.actionable ?? true,
          data: metrics,
          businessId,
        },
      });
    }

    // Log the AI query
    await prisma.aIQueryLog.create({
      data: {
        type: 'GENERAL_QUERY',
        query: 'Weekly insight generation',
        context: metrics,
        response: text,
        model: 'claude-haiku',
        tokensUsed,
        latencyMs: 0,
        userId: 'system',
        businessId,
      },
    });

    console.log(
      `[InsightGenerator] Generated ${insights.length} insights for business ${businessId}`,
    );
  } catch (error) {
    console.error('[InsightGenerator] Failed to generate insights:', error);
  }
}

/**
 * Get active (non-dismissed) insight cards for a business.
 */
export async function getInsights(
  businessId: string,
): Promise<unknown[]> {
  return prisma.insightCard.findMany({
    where: { businessId, isDismissed: false },
    orderBy: { createdAt: 'desc' },
    take: 20,
  });
}

/**
 * Dismiss an insight card.
 */
export async function dismissInsight(
  businessId: string,
  insightId: string,
): Promise<void> {
  await prisma.insightCard.updateMany({
    where: { id: insightId, businessId },
    data: { isDismissed: true },
  });
}
