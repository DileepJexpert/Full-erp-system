import jwt from 'jsonwebtoken';
import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../../utils/errors.js';
import { getEnv } from '../../config/env.js';

// ─── Kiosk JWT ───────────────────────────────────────────────

interface KioskTokenPayload {
  deviceId: string;
  locationId: string;
  businessId: string;
  type: 'kiosk';
}

function signKioskToken(payload: KioskTokenPayload): string {
  const env = getEnv();
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: '365d' });
}

export function verifyKioskToken(token: string): KioskTokenPayload {
  const env = getEnv();
  const decoded = jwt.verify(token, env.JWT_SECRET) as KioskTokenPayload;
  if (decoded.type !== 'kiosk') {
    throw new UnauthorizedError('Invalid kiosk token');
  }
  return decoded;
}

// ─── Authenticate Kiosk ─────────────────────────────────────

export async function authenticateKiosk(input: {
  deviceId: string;
  locationPin: string;
  deviceName: string;
  businessId: string;
}): Promise<{
  kioskToken: string;
  locationId: string;
  locationName: string;
  businessName: string;
  displayMode: string;
  autoResetSec: number;
  showBilingual: boolean;
  negativeTags: string[];
  positiveTags: string[];
}> {
  // Look up existing device
  const existing = await prisma.kioskDevice.findUnique({
    where: { deviceId_businessId: { deviceId: input.deviceId, businessId: input.businessId } },
  });

  let locationId: string;

  if (existing) {
    // Verify PIN matches
    if (existing.locationPin !== input.locationPin) {
      throw new UnauthorizedError('Invalid location PIN');
    }
    locationId = existing.locationId;

    // Update device name and lastSeenAt
    await prisma.kioskDevice.update({
      where: { id: existing.id },
      data: { deviceName: input.deviceName, lastSeenAt: new Date(), isActive: true },
    });
  } else {
    // Find location by PIN within the business
    const location = await prisma.location.findFirst({
      where: { businessId: input.businessId, feedbackKioskEnabled: true },
    });

    if (!location) {
      throw new NotFoundError('No kiosk-enabled location found for this business');
    }

    locationId = location.id;

    // Create new kiosk device
    await prisma.kioskDevice.create({
      data: {
        deviceId: input.deviceId,
        deviceName: input.deviceName,
        locationId,
        locationPin: input.locationPin,
        businessId: input.businessId,
        isActive: true,
        lastSeenAt: new Date(),
      },
    });
  }

  // Fetch location + business details
  const location = await prisma.location.findUniqueOrThrow({
    where: { id: locationId },
    select: {
      id: true,
      name: true,
      feedbackDisplayMode: true,
      feedbackAutoResetSec: true,
      feedbackShowBilingual: true,
      feedbackNegativeTags: true,
      feedbackPositiveTags: true,
      business: { select: { name: true } },
    },
  });

  const kioskToken = signKioskToken({
    deviceId: input.deviceId,
    locationId,
    businessId: input.businessId,
    type: 'kiosk',
  });

  return {
    kioskToken,
    locationId: location.id,
    locationName: location.name,
    businessName: location.business.name,
    displayMode: location.feedbackDisplayMode,
    autoResetSec: location.feedbackAutoResetSec,
    showBilingual: location.feedbackShowBilingual,
    negativeTags: location.feedbackNegativeTags,
    positiveTags: location.feedbackPositiveTags,
  };
}

// ─── Get Last Bill at Location (within 15 min) ─────────────

export async function getLastBillAtLocation(
  businessId: string,
  locationId: string,
): Promise<{ id: string; operatorId: string } | null> {
  const fifteenMinAgo = new Date(Date.now() - 15 * 60 * 1000);

  const bill = await prisma.bill.findFirst({
    where: {
      businessId,
      locationId,
      createdAt: { gte: fifteenMinAgo },
    },
    orderBy: { createdAt: 'desc' },
    select: { id: true, operatorId: true },
  });

  return bill;
}

// ─── Check Critical Feedback ────────────────────────────────

export async function checkCriticalFeedback(
  businessId: string,
  locationId: string,
): Promise<boolean> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  const badCount = await prisma.customerFeedback.count({
    where: {
      businessId,
      locationId,
      rating: { lte: 2 },
      createdAt: { gte: oneHourAgo },
    },
  });

  return badCount >= 3;
}

// ─── Submit Feedback ────────────────────────────────────────

export async function submitFeedback(input: {
  rating: number;
  comment?: string;
  tags?: string[];
  locationId: string;
  businessId: string;
  billId?: string;
  operatorId?: string;
  deviceId?: string;
  channel: string;
}): Promise<any> {
  let { billId, operatorId } = input;

  // Auto-link to last bill if not provided
  if (!billId) {
    const lastBill = await getLastBillAtLocation(input.businessId, input.locationId);
    if (lastBill) {
      billId = lastBill.id;
      operatorId = operatorId ?? lastBill.operatorId;
    }
  }

  const feedback = await prisma.customerFeedback.create({
    data: {
      rating: input.rating,
      comment: input.comment ?? null,
      tags: input.tags ?? [],
      channel: input.channel,
      entryDevice: input.deviceId ?? null,
      billId: billId ?? null,
      operatorId: operatorId ?? null,
      locationId: input.locationId,
      businessId: input.businessId,
    },
  });

  // Check critical threshold for bad ratings
  if (input.rating <= 2) {
    const isCritical = await checkCriticalFeedback(input.businessId, input.locationId);
    if (isCritical) {
      // Create critical alert
      await prisma.alert.create({
        data: {
          type: 'PATTERN_DETECTED',
          severity: 'CRITICAL',
          title: 'Multiple negative feedback detected',
          description: `3 or more negative ratings (1-2 stars) received at this location in the last hour.`,
          businessId: input.businessId,
          locationId: input.locationId,
          operatorId: operatorId ?? null,
          data: {
            feedbackId: feedback.id,
            rating: input.rating,
            channel: input.channel,
          },
        },
      });
    }
  }

  return feedback;
}

// ─── Feedback Summary ───────────────────────────────────────

export async function getFeedbackSummary(
  businessId: string,
  locationId?: string,
  startDate?: Date,
  endDate?: Date,
): Promise<{
  avgRating: number;
  totalFeedback: number;
  ratingDistribution: { rating: number; count: number }[];
  topTags: { tag: string; count: number }[];
  npsScore: number;
  trend: { date: string; avgRating: number; count: number }[];
}> {
  const where: Record<string, unknown> = { businessId };
  if (locationId) where.locationId = locationId;
  if (startDate || endDate) {
    const dateFilter: Record<string, Date> = {};
    if (startDate) dateFilter.gte = startDate;
    if (endDate) dateFilter.lte = endDate;
    where.createdAt = dateFilter;
  }

  // Aggregate stats
  const [aggregate, allFeedback] = await Promise.all([
    prisma.customerFeedback.aggregate({
      where,
      _avg: { rating: true },
      _count: { id: true },
    }),
    prisma.customerFeedback.findMany({
      where,
      select: { rating: true, tags: true, createdAt: true },
    }),
  ]);

  const totalFeedback = aggregate._count.id;
  const avgRating = Math.round((aggregate._avg.rating ?? 0) * 100) / 100;

  // Rating distribution
  const ratingCounts = new Map<number, number>();
  for (let i = 1; i <= 5; i++) ratingCounts.set(i, 0);
  for (const fb of allFeedback) {
    ratingCounts.set(fb.rating, (ratingCounts.get(fb.rating) ?? 0) + 1);
  }
  const ratingDistribution = Array.from(ratingCounts.entries()).map(([rating, count]) => ({
    rating,
    count,
  }));

  // Top tags
  const tagCounts = new Map<string, number>();
  for (const fb of allFeedback) {
    for (const tag of fb.tags) {
      tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
    }
  }
  const topTags = Array.from(tagCounts.entries())
    .map(([tag, count]) => ({ tag, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10);

  // NPS
  const promoters = allFeedback.filter((f) => f.rating >= 4).length;
  const detractors = allFeedback.filter((f) => f.rating <= 2).length;
  const npsScore = totalFeedback > 0
    ? Math.round(((promoters - detractors) / totalFeedback) * 100)
    : 0;

  // Trend: group by day for last 30 days
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const trendMap = new Map<string, { totalRating: number; count: number }>();
  for (const fb of allFeedback) {
    if (fb.createdAt < thirtyDaysAgo) continue;
    const dateKey = fb.createdAt.toISOString().slice(0, 10);
    const entry = trendMap.get(dateKey) ?? { totalRating: 0, count: 0 };
    entry.totalRating += fb.rating;
    entry.count += 1;
    trendMap.set(dateKey, entry);
  }
  const trend = Array.from(trendMap.entries())
    .map(([date, entry]) => ({
      date,
      avgRating: Math.round((entry.totalRating / entry.count) * 100) / 100,
      count: entry.count,
    }))
    .sort((a, b) => a.date.localeCompare(b.date));

  return { avgRating, totalFeedback, ratingDistribution, topTags, npsScore, trend };
}

// ─── NPS Breakdown ──────────────────────────────────────────

export async function getNpsBreakdown(
  businessId: string,
  locationId?: string,
  startDate?: Date,
  endDate?: Date,
): Promise<{
  nps: number;
  promoters: number;
  passives: number;
  detractors: number;
  promotersPct: number;
  passivesPct: number;
  detractorsPct: number;
  byLocation: Array<{ locationId: string; locationName: string; nps: number; count: number }>;
}> {
  const where: Record<string, unknown> = { businessId };
  if (locationId) where.locationId = locationId;
  if (startDate || endDate) {
    const dateFilter: Record<string, Date> = {};
    if (startDate) dateFilter.gte = startDate;
    if (endDate) dateFilter.lte = endDate;
    where.createdAt = dateFilter;
  }

  const allFeedback = await prisma.customerFeedback.findMany({
    where,
    select: { rating: true, locationId: true },
  });

  const total = allFeedback.length;
  const promoters = allFeedback.filter((f) => f.rating >= 4).length;
  const detractors = allFeedback.filter((f) => f.rating <= 2).length;
  const passives = total - promoters - detractors;

  const promotersPct = total > 0 ? Math.round((promoters / total) * 100) : 0;
  const passivesPct = total > 0 ? Math.round((passives / total) * 100) : 0;
  const detractorsPct = total > 0 ? Math.round((detractors / total) * 100) : 0;
  const nps = promotersPct - detractorsPct;

  // Group by location
  const byLocMap = new Map<string, number[]>();
  for (const fb of allFeedback) {
    const ratings = byLocMap.get(fb.locationId) ?? [];
    ratings.push(fb.rating);
    byLocMap.set(fb.locationId, ratings);
  }

  const locationIds = Array.from(byLocMap.keys());
  const locations = await prisma.location.findMany({
    where: { id: { in: locationIds } },
    select: { id: true, name: true },
  });
  const locNameMap = new Map(locations.map((l) => [l.id, l.name]));

  const byLocation = Array.from(byLocMap.entries()).map(([locId, ratings]) => {
    const locTotal = ratings.length;
    const locPromoters = ratings.filter((r) => r >= 4).length;
    const locDetractors = ratings.filter((r) => r <= 2).length;
    const locNps = locTotal > 0
      ? Math.round(((locPromoters - locDetractors) / locTotal) * 100)
      : 0;

    return {
      locationId: locId,
      locationName: locNameMap.get(locId) ?? 'Unknown',
      nps: locNps,
      count: locTotal,
    };
  });

  return { nps, promoters, passives, detractors, promotersPct, passivesPct, detractorsPct, byLocation };
}

// ─── List Feedback ──────────────────────────────────────────

export async function listFeedback(
  businessId: string,
  query: {
    locationId?: string;
    rating?: number;
    startDate?: string;
    endDate?: string;
    page: number;
    limit: number;
  },
): Promise<{ data: any[]; pagination: any }> {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.rating) where.rating = query.rating;

  if (query.startDate || query.endDate) {
    const dateFilter: Record<string, Date> = {};
    if (query.startDate) dateFilter.gte = new Date(query.startDate);
    if (query.endDate) dateFilter.lte = new Date(query.endDate);
    where.createdAt = dateFilter;
  }

  const skip = (query.page - 1) * query.limit;

  const [data, total] = await Promise.all([
    prisma.customerFeedback.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: query.limit,
      skip,
    }),
    prisma.customerFeedback.count({ where }),
  ]);

  return {
    data,
    pagination: {
      page: query.page,
      limit: query.limit,
      total,
      totalPages: Math.ceil(total / query.limit),
    },
  };
}
