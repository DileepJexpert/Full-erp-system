import { prisma } from '../lib/prisma.js';
import { runAnomalyScan } from '../modules/alerts/anomaly.service.js';

export async function anomalyScanJob(): Promise<void> {
  console.log('[JOB] Starting nightly anomaly scan...');

  const businesses = await prisma.business.findMany({
    where: { enableAnomaly: true },
    select: { id: true, name: true },
  });

  for (const business of businesses) {
    try {
      const alertsCreated = await runAnomalyScan(business.id);
      console.log(`[JOB] Anomaly scan for ${business.name}: ${alertsCreated} alerts created`);
    } catch (err) {
      console.error(`[JOB] Anomaly scan failed for ${business.name}:`, err);
    }
  }

  console.log('[JOB] Anomaly scan completed');
}
