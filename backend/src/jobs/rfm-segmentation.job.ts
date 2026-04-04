import { prisma } from '../lib/prisma.js';
import { calculateRFMSegments } from '../modules/analytics/rfm.service.js';

/**
 * Weekly Monday 3 AM: recalculate RFM segments for each business.
 * Stores segment summaries as InsightCards for business owners.
 */
export async function runRFMSegmentationJob(): Promise<void> {
  console.log('[JOB] rfm-segmentation: starting...');

  const businesses = await prisma.business.findMany({
    where: { enableAI: true },
    select: { id: true, name: true },
  });

  let processedCount = 0;

  for (const business of businesses) {
    try {
      // Check if business has any customers
      const customerCount = await prisma.customer.count({
        where: { businessId: business.id },
      });

      if (customerCount === 0) {
        console.log(`[JOB] rfm-segmentation: skipping "${business.name}" (no customers)`);
        continue;
      }

      const segments = await calculateRFMSegments(business.id);

      // Generate insight cards from segmentation results
      const atRisk = segments.find((s) => s.segment === 'AtRisk');
      const champions = segments.find((s) => s.segment === 'Champions');
      const dormant = segments.find((s) => s.segment === 'Dormant');

      const insights: Array<{
        title: string;
        description: string;
        category: string;
        actionable: boolean;
        data: Record<string, unknown>;
      }> = [];

      // Insight: At-risk customers needing attention
      if (atRisk && atRisk.count > 0) {
        insights.push({
          title: `${atRisk.count} At-Risk Customers`,
          description: `${atRisk.count} previously regular customers haven't visited recently. Average spend: ${atRisk.avgSpend}. Consider a re-engagement campaign.`,
          category: 'customer',
          actionable: true,
          data: {
            segment: 'AtRisk',
            count: atRisk.count,
            avgSpend: atRisk.avgSpend,
            topCustomers: atRisk.customers.slice(0, 5).map((c) => ({
              name: c.name,
              phone: c.phone,
              lastVisit: c.lastVisit,
              totalSpent: c.totalSpent,
            })),
          },
        });
      }

      // Insight: Champions summary
      if (champions && champions.count > 0) {
        insights.push({
          title: `${champions.count} Champion Customers`,
          description: `Your top ${champions.count} customers spend an average of ${champions.avgSpend} and visit frequently. Keep them engaged with loyalty rewards.`,
          category: 'customer',
          actionable: false,
          data: {
            segment: 'Champions',
            count: champions.count,
            avgSpend: champions.avgSpend,
          },
        });
      }

      // Insight: Dormant customers
      if (dormant && dormant.count > 0 && dormant.count > customerCount * 0.3) {
        insights.push({
          title: `High Dormant Customer Rate`,
          description: `${dormant.count} out of ${customerCount} customers (${Math.round((dormant.count / customerCount) * 100)}%) are dormant. Consider running a win-back promotion.`,
          category: 'customer',
          actionable: true,
          data: {
            segment: 'Dormant',
            count: dormant.count,
            totalCustomers: customerCount,
            percentage: Math.round((dormant.count / customerCount) * 100),
          },
        });
      }

      // Store segment summary insight
      insights.push({
        title: 'Weekly Customer Segmentation',
        description: `RFM analysis: ${champions?.count ?? 0} Champions, ${segments.find((s) => s.segment === 'Loyal')?.count ?? 0} Loyal, ${segments.find((s) => s.segment === 'New')?.count ?? 0} New, ${atRisk?.count ?? 0} At-Risk, ${dormant?.count ?? 0} Dormant.`,
        category: 'customer',
        actionable: false,
        data: {
          segments: segments.map((s) => ({
            segment: s.segment,
            count: s.count,
            avgSpend: s.avgSpend,
          })),
          totalCustomers: customerCount,
        },
      });

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
      }

      processedCount++;
      console.log(
        `[JOB] rfm-segmentation: processed "${business.name}" - ${customerCount} customers, ${insights.length} insights`,
      );
    } catch (err) {
      console.error(`[JOB] rfm-segmentation: failed for "${business.name}":`, err);
    }
  }

  console.log(`[JOB] rfm-segmentation: completed. ${processedCount} businesses processed.`);
}
