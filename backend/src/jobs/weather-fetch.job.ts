import { prisma } from '../lib/prisma.js';
import { fetchAndStoreWeather } from '../modules/weather/weather.service.js';

export async function weatherFetchJob(): Promise<void> {
  console.log('[JOB] Starting daily weather fetch...');

  const businesses = await prisma.business.findMany({
    where: { enableWeather: true },
    select: { id: true, name: true },
  });

  for (const business of businesses) {
    try {
      const stored = await fetchAndStoreWeather(business.id);
      console.log(`[JOB] Weather fetch for ${business.name}: ${stored} locations updated`);
    } catch (err) {
      console.error(`[JOB] Weather fetch failed for ${business.name}:`, err);
    }
  }

  console.log('[JOB] Weather fetch completed');
}
