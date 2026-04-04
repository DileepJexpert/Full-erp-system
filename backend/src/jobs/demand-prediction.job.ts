import { prisma } from '../lib/prisma.js';

/**
 * Daily 5 AM: predict tomorrow's demand for each active item at each active location.
 * Skip items with < 30 days of billing data.
 */
export async function runDemandPredictionJob(): Promise<void> {
  console.log('[JOB] demand-prediction: starting...');

  const businesses = await prisma.business.findMany({
    where: { enableAI: true },
    select: { id: true, name: true },
  });

  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  let totalPredictions = 0;

  for (const business of businesses) {
    try {
      const locations = await prisma.location.findMany({
        where: { businessId: business.id, isActive: true },
        select: { id: true, name: true },
      });

      const items = await prisma.item.findMany({
        where: { businessId: business.id, isActive: true },
        select: { id: true, name: true },
      });

      for (const location of locations) {
        for (const item of items) {
          // Get historical daily sales for this item at this location
          const billItems = await prisma.billItem.findMany({
            where: {
              itemId: item.id,
              bill: {
                businessId: business.id,
                locationId: location.id,
                date: { gte: thirtyDaysAgo },
              },
            },
            include: {
              bill: { select: { date: true } },
            },
          });

          // Skip items with < 30 days of data
          const uniqueDays = new Set(
            billItems.map((bi) => bi.bill.date.toISOString().split('T')[0]),
          );
          if (uniqueDays.size < 30) continue;

          // Aggregate daily quantities
          const dailyQty = new Map<string, number>();
          for (const bi of billItems) {
            const day = bi.bill.date.toISOString().split('T')[0];
            dailyQty.set(day, (dailyQty.get(day) ?? 0) + bi.quantity);
          }

          const quantities = [...dailyQty.values()];
          const avgQty = quantities.reduce((s, q) => s + q, 0) / quantities.length;
          const stdDev = Math.sqrt(
            quantities.reduce((s, q) => s + (q - avgQty) ** 2, 0) / quantities.length,
          );

          // Day-of-week factor: compare tomorrow's weekday average to overall average
          const tomorrowDay = tomorrow.getDay();
          const dayEntries = [...dailyQty.entries()].filter(
            ([dateStr]) => new Date(dateStr).getDay() === tomorrowDay,
          );
          const dayAvg =
            dayEntries.length > 0
              ? dayEntries.reduce((s, [, q]) => s + q, 0) / dayEntries.length
              : avgQty;
          const dowFactor = avgQty > 0 ? dayAvg / avgQty : 1;

          // Simple trend: compare last 7 days average to overall
          const sevenDaysAgo = new Date();
          sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
          const recentEntries = [...dailyQty.entries()].filter(
            ([dateStr]) => new Date(dateStr) >= sevenDaysAgo,
          );
          const recentAvg =
            recentEntries.length > 0
              ? recentEntries.reduce((s, [, q]) => s + q, 0) / recentEntries.length
              : avgQty;
          const trendFactor = avgQty > 0 ? recentAvg / avgQty : 1;

          // Predicted quantity: base average adjusted by day-of-week and trend
          const predicted = Math.max(1, Math.round(avgQty * dowFactor * trendFactor));

          // Confidence based on coefficient of variation
          const cv = avgQty > 0 ? stdDev / avgQty : 1;
          const confidence = Math.max(0.1, Math.min(1.0, 1 - cv));

          // Upsert prediction
          await prisma.demandPrediction.upsert({
            where: {
              itemId_locationId_date: {
                itemId: item.id,
                locationId: location.id,
                date: tomorrow,
              },
            },
            create: {
              date: tomorrow,
              predictedQty: predicted,
              confidence: Math.round(confidence * 100) / 100,
              factors: {
                avgQty: Math.round(avgQty * 100) / 100,
                dowFactor: Math.round(dowFactor * 100) / 100,
                trendFactor: Math.round(trendFactor * 100) / 100,
                dataPoints: uniqueDays.size,
              },
              itemId: item.id,
              locationId: location.id,
              businessId: business.id,
            },
            update: {
              predictedQty: predicted,
              confidence: Math.round(confidence * 100) / 100,
              factors: {
                avgQty: Math.round(avgQty * 100) / 100,
                dowFactor: Math.round(dowFactor * 100) / 100,
                trendFactor: Math.round(trendFactor * 100) / 100,
                dataPoints: uniqueDays.size,
              },
            },
          });

          totalPredictions++;
        }
      }

      console.log(`[JOB] demand-prediction: processed business "${business.name}"`);
    } catch (err) {
      console.error(`[JOB] demand-prediction: failed for business "${business.name}":`, err);
    }
  }

  console.log(`[JOB] demand-prediction: completed. ${totalPredictions} predictions generated.`);
}
