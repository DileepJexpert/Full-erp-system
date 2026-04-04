import { prisma } from '../../lib/prisma.js';
import { fetchWeather } from '../../lib/weather-api.js';

export async function fetchAndStoreWeather(businessId: string): Promise<number> {
  const locations = await prisma.location.findMany({
    where: { businessId, isActive: true, latitude: { not: null }, longitude: { not: null } },
  });

  let stored = 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  for (const loc of locations) {
    if (!loc.latitude || !loc.longitude) continue;

    try {
      const weather = await fetchWeather(loc.latitude, loc.longitude);

      await prisma.weatherLog.upsert({
        where: { locationId_date: { locationId: loc.id, date: today } },
        create: {
          businessId,
          locationId: loc.id,
          date: today,
          tempHigh: weather.tempHigh,
          tempLow: weather.tempLow,
          condition: weather.condition as any,
          humidity: weather.humidity,
        },
        update: {
          tempHigh: weather.tempHigh,
          tempLow: weather.tempLow,
          condition: weather.condition as any,
          humidity: weather.humidity,
        },
      });
      stored++;
    } catch (err) {
      console.error(`Weather fetch failed for location ${loc.id}:`, err);
    }
  }

  return stored;
}

export async function getWeatherLogs(businessId: string, locationId?: string, days = 7) {
  const since = new Date();
  since.setDate(since.getDate() - days);
  since.setHours(0, 0, 0, 0);

  const where: Record<string, unknown> = { businessId, date: { gte: since } };
  if (locationId) where.locationId = locationId;

  return prisma.weatherLog.findMany({
    where,
    include: { location: { select: { id: true, name: true } } },
    orderBy: { date: 'desc' },
  });
}

export async function getWeatherCorrelation(businessId: string, locationId: string, days = 30) {
  const since = new Date();
  since.setDate(since.getDate() - days);

  const [weatherLogs, bills] = await Promise.all([
    prisma.weatherLog.findMany({
      where: { businessId, locationId, date: { gte: since } },
      orderBy: { date: 'asc' },
    }),
    prisma.bill.findMany({
      where: { businessId, locationId, date: { gte: since } },
    }),
  ]);

  // Group bills by date
  const revenueByDate = new Map<string, number>();
  for (const bill of bills) {
    const dateStr = bill.date.toISOString().split('T')[0];
    revenueByDate.set(dateStr, (revenueByDate.get(dateStr) ?? 0) + bill.total);
  }

  return weatherLogs.map((w) => ({
    date: w.date,
    condition: w.condition,
    tempHigh: w.tempHigh,
    tempLow: w.tempLow,
    humidity: w.humidity,
    revenue: revenueByDate.get(w.date.toISOString().split('T')[0]) ?? 0,
  }));
}
