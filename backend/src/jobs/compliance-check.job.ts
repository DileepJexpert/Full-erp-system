import { prisma } from '../lib/prisma.js';
import { checkExpiringDocs } from '../modules/compliance/compliance.service.js';

export async function complianceCheckJob(): Promise<void> {
  console.log('[JOB] Starting daily compliance check...');

  const businesses = await prisma.business.findMany({
    select: { id: true, name: true },
  });

  for (const business of businesses) {
    try {
      const updated = await checkExpiringDocs(business.id);
      if (updated > 0) {
        console.log(`[JOB] Compliance check for ${business.name}: ${updated} docs updated`);
      }
    } catch (err) {
      console.error(`[JOB] Compliance check failed for ${business.name}:`, err);
    }
  }

  console.log('[JOB] Compliance check completed');
}
