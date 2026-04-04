import { prisma } from '../lib/prisma.js';

/**
 * Weekly Sunday 2 AM: generate insight cards for each business with 30+ days of data.
 */
export async function runInsightGenerationJob(): Promise<void> {
  console.log('[JOB] insight-generation: starting...');

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  // Find businesses that have at least one bill from 30+ days ago
  const businesses = await prisma.business.findMany({
    where: {
      enableAI: true,
    },
    select: { id: true, name: true },
  });

  let totalInsights = 0;

  for (const business of businesses) {
    try {
      // Verify the business has 30+ days of data
      const oldestBill = await prisma.bill.findFirst({
        where: { businessId: business.id },
        orderBy: { date: 'asc' },
        select: { date: true },
      });

      if (!oldestBill || oldestBill.date > thirtyDaysAgo) {
        console.log(`[JOB] insight-generation: skipping "${business.name}" (< 30 days of data)`);
        continue;
      }

      const insights: Array<{
        title: string;
        description: string;
        category: string;
        actionable: boolean;
        data: Record<string, unknown>;
      }> = [];

      // --- Insight 1: Revenue trend ---
      const lastWeekStart = new Date();
      lastWeekStart.setDate(lastWeekStart.getDate() - 7);
      const prevWeekStart = new Date();
      prevWeekStart.setDate(prevWeekStart.getDate() - 14);

      const [thisWeekRev, prevWeekRev] = await Promise.all([
        prisma.bill.aggregate({
          where: { businessId: business.id, date: { gte: lastWeekStart } },
          _sum: { total: true },
        }),
        prisma.bill.aggregate({
          where: { businessId: business.id, date: { gte: prevWeekStart, lt: lastWeekStart } },
          _sum: { total: true },
        }),
      ]);

      const thisTotal = thisWeekRev._sum.total ?? 0;
      const prevTotal = prevWeekRev._sum.total ?? 0;

      if (prevTotal > 0) {
        const changePct = ((thisTotal - prevTotal) / prevTotal) * 100;
        const rounded = Math.round(changePct * 10) / 10;
        if (Math.abs(rounded) >= 5) {
          insights.push({
            title: rounded > 0 ? 'Revenue Up This Week' : 'Revenue Down This Week',
            description: `Weekly revenue ${rounded > 0 ? 'increased' : 'decreased'} by ${Math.abs(rounded)}% compared to the previous week.`,
            category: 'revenue',
            actionable: rounded < 0,
            data: { thisWeek: thisTotal, prevWeek: prevTotal, changePct: rounded },
          });
        }
      }

      // --- Insight 2: Top performing item ---
      const topItems = await prisma.billItem.groupBy({
        by: ['itemId'],
        where: {
          bill: { businessId: business.id, date: { gte: lastWeekStart } },
        },
        _sum: { lineTotal: true, quantity: true },
        orderBy: { _sum: { lineTotal: 'desc' } },
        take: 1,
      });

      if (topItems.length > 0) {
        const topItem = await prisma.item.findUnique({
          where: { id: topItems[0].itemId },
          select: { name: true },
        });
        if (topItem) {
          insights.push({
            title: 'Top Selling Item This Week',
            description: `"${topItem.name}" generated the most revenue this week with ${topItems[0]._sum.quantity ?? 0} units sold.`,
            category: 'product',
            actionable: false,
            data: {
              itemId: topItems[0].itemId,
              itemName: topItem.name,
              revenue: topItems[0]._sum.lineTotal ?? 0,
              quantity: topItems[0]._sum.quantity ?? 0,
            },
          });
        }
      }

      // --- Insight 3: Expense anomaly ---
      const weeklyExpense = await prisma.expense.aggregate({
        where: { businessId: business.id, date: { gte: lastWeekStart } },
        _sum: { amount: true },
      });
      const avgWeeklyExpense = await prisma.expense.aggregate({
        where: { businessId: business.id, date: { gte: thirtyDaysAgo } },
        _sum: { amount: true },
        _count: true,
      });

      const weekExpenseTotal = weeklyExpense._sum.amount ?? 0;
      const monthExpenseTotal = avgWeeklyExpense._sum.amount ?? 0;
      const avgWeekly = monthExpenseTotal / 4; // approximate 4 weeks in 30 days

      if (avgWeekly > 0 && weekExpenseTotal > avgWeekly * 1.3) {
        const overPct = Math.round(((weekExpenseTotal - avgWeekly) / avgWeekly) * 100);
        insights.push({
          title: 'Expense Spike Detected',
          description: `This week's expenses are ${overPct}% above your 30-day weekly average. Review recent expenses.`,
          category: 'expense',
          actionable: true,
          data: {
            thisWeek: weekExpenseTotal,
            weeklyAvg: Math.round(avgWeekly * 100) / 100,
            overPct,
          },
        });
      }

      // --- Insight 4: Customer growth ---
      const newCustomers = await prisma.customer.count({
        where: { businessId: business.id, createdAt: { gte: lastWeekStart } },
      });
      const prevNewCustomers = await prisma.customer.count({
        where: { businessId: business.id, createdAt: { gte: prevWeekStart, lt: lastWeekStart } },
      });

      if (newCustomers > 0 || prevNewCustomers > 0) {
        insights.push({
          title: 'Customer Acquisition',
          description: `${newCustomers} new customers this week${prevNewCustomers > 0 ? ` vs ${prevNewCustomers} last week` : ''}.`,
          category: 'customer',
          actionable: false,
          data: { newCustomers, prevNewCustomers },
        });
      }

      // --- Insight 5: Low stock warnings ---
      const lowStockItems = await prisma.item.findMany({
        where: {
          businessId: business.id,
          isActive: true,
          minStockLevel: { not: null },
        },
        select: { id: true, name: true, centralStock: true, minStockLevel: true },
      });

      const criticalItems = lowStockItems.filter(
        (i) => i.minStockLevel !== null && i.centralStock <= i.minStockLevel,
      );

      if (criticalItems.length > 0) {
        insights.push({
          title: `${criticalItems.length} Items Below Minimum Stock`,
          description: `Items at critical stock levels: ${criticalItems.slice(0, 5).map((i) => i.name).join(', ')}${criticalItems.length > 5 ? ` and ${criticalItems.length - 5} more` : ''}.`,
          category: 'inventory',
          actionable: true,
          data: {
            count: criticalItems.length,
            items: criticalItems.slice(0, 10).map((i) => ({
              id: i.id,
              name: i.name,
              stock: i.centralStock,
              minLevel: i.minStockLevel,
            })),
          },
        });
      }

      // Persist insights
      if (insights.length > 0) {
        await prisma.insightCard.createMany({
          data: insights.map((insight) => ({
            title: insight.title,
            description: insight.description,
            category: insight.category,
            actionable: insight.actionable,
            data: insight.data,
            businessId: business.id,
          })),
        });
        totalInsights += insights.length;
      }

      console.log(`[JOB] insight-generation: ${insights.length} insights for "${business.name}"`);
    } catch (err) {
      console.error(`[JOB] insight-generation: failed for "${business.name}":`, err);
    }
  }

  console.log(`[JOB] insight-generation: completed. ${totalInsights} insights generated.`);
}
