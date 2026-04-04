import { prisma } from '../lib/prisma.js';
import { computePerformanceScores } from '../modules/performance/performance.service.js';
import { cacheSet } from '../lib/redis.js';

export async function performanceCalcJob(): Promise<void> {
  console.log('[JOB] Starting weekly performance calculation...');

  const businesses = await prisma.business.findMany({
    where: { enablePerformance: true },
    select: { id: true, name: true },
  });

  const endDate = new Date();
  const startDate = new Date(endDate.getTime() - 7 * 24 * 60 * 60 * 1000);

  for (const business of businesses) {
    try {
      const scores = await computePerformanceScores(business.id, startDate, endDate);
      await cacheSet(`performance:${business.id}:weekly`, scores, 7 * 24 * 60 * 60);
      console.log(`[JOB] Performance calc for ${business.name}: ${scores.length} operators scored`);
    } catch (err) {
      console.error(`[JOB] Performance calc failed for ${business.name}:`, err);
    }
  }

  console.log('[JOB] Performance calculation completed');
}
