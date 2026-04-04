import { prisma } from '../../lib/prisma.js';

export interface CustomerSegment {
  segment: 'Champions' | 'Loyal' | 'AtRisk' | 'New' | 'Dormant';
  count: number;
  avgSpend: number;
  customers: Array<{
    id: string;
    name: string;
    phone: string;
    rfmScore: string;
    lastVisit: Date;
    totalSpent: number;
  }>;
}

interface CustomerRFM {
  id: string;
  name: string;
  phone: string;
  totalVisits: number;
  recency: number;   // days since last bill
  frequency: number; // number of bills in 90 days
  monetary: number;  // total spend in 90 days
  rScore: number;
  fScore: number;
  mScore: number;
  lastVisit: Date;
}

function scoreQuintile(values: number[], value: number, ascending: boolean): number {
  const sorted = [...values].sort((a, b) => a - b);
  const len = sorted.length;
  if (len === 0) return 3;

  const quintiles = [
    sorted[Math.floor(len * 0.2)] ?? sorted[0],
    sorted[Math.floor(len * 0.4)] ?? sorted[0],
    sorted[Math.floor(len * 0.6)] ?? sorted[0],
    sorted[Math.floor(len * 0.8)] ?? sorted[0],
  ];

  let score: number;
  if (value <= quintiles[0]) score = 1;
  else if (value <= quintiles[1]) score = 2;
  else if (value <= quintiles[2]) score = 3;
  else if (value <= quintiles[3]) score = 4;
  else score = 5;

  // For recency, lower days = better, so invert
  return ascending ? score : 6 - score;
}

function classifySegment(c: CustomerRFM): CustomerSegment['segment'] {
  // New customers: very few total visits regardless of RFM
  if (c.totalVisits <= 3) return 'New';

  // Champions: high on all dimensions
  if (c.rScore >= 4 && c.fScore >= 4 && c.mScore >= 4) return 'Champions';

  // Loyal: reasonably good across dimensions
  if (c.rScore >= 3 && c.fScore >= 3 && c.mScore >= 3) return 'Loyal';

  // AtRisk: were regular (high frequency) but stopped coming (low recency)
  if (c.rScore <= 2 && c.fScore >= 3) return 'AtRisk';

  // Dormant: haven't come recently and weren't frequent
  if (c.rScore === 1 && c.fScore <= 2) return 'Dormant';

  // Default: assign to Loyal if decent, else Dormant
  if (c.rScore + c.fScore + c.mScore >= 9) return 'Loyal';
  return 'Dormant';
}

export async function calculateRFMSegments(businessId: string): Promise<CustomerSegment[]> {
  const now = new Date();
  const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

  // 1. Get all customers with their bills from last 90 days
  const customers = await prisma.customer.findMany({
    where: { businessId },
    include: {
      bills: {
        where: {
          date: { gte: ninetyDaysAgo },
        },
        select: {
          date: true,
          total: true,
        },
        orderBy: { date: 'desc' },
      },
    },
  });

  if (customers.length === 0) {
    return buildEmptySegments();
  }

  // 2. Calculate raw RFM values for each customer
  const rfmData: CustomerRFM[] = customers.map((c) => {
    const billCount = c.bills.length;
    const totalSpend = c.bills.reduce((sum, b) => sum + b.total, 0);
    const lastBillDate = c.bills[0]?.date ?? c.createdAt;
    const daysSinceLastBill = Math.floor(
      (now.getTime() - new Date(lastBillDate).getTime()) / (1000 * 60 * 60 * 24),
    );

    return {
      id: c.id,
      name: c.name ?? 'Unknown',
      phone: c.phone,
      totalVisits: c.totalVisits,
      recency: daysSinceLastBill,
      frequency: billCount,
      monetary: totalSpend,
      rScore: 0,
      fScore: 0,
      mScore: 0,
      lastVisit: new Date(lastBillDate),
    };
  });

  // 3. Score each dimension 1-5 using quintile distribution
  const recencies = rfmData.map((c) => c.recency);
  const frequencies = rfmData.map((c) => c.frequency);
  const monetaries = rfmData.map((c) => c.monetary);

  for (const c of rfmData) {
    // Recency: lower = better, so ascending=false to invert
    c.rScore = scoreQuintile(recencies, c.recency, false);
    // Frequency: higher = better
    c.fScore = scoreQuintile(frequencies, c.frequency, true);
    // Monetary: higher = better
    c.mScore = scoreQuintile(monetaries, c.monetary, true);
  }

  // 4. Segment based on RFM combination
  const segmentMap = new Map<CustomerSegment['segment'], CustomerRFM[]>();
  const allSegments: CustomerSegment['segment'][] = ['Champions', 'Loyal', 'AtRisk', 'New', 'Dormant'];
  for (const seg of allSegments) {
    segmentMap.set(seg, []);
  }

  for (const c of rfmData) {
    const segment = classifySegment(c);
    segmentMap.get(segment)!.push(c);
  }

  // 5. Build result
  const result: CustomerSegment[] = allSegments.map((segment) => {
    const custs = segmentMap.get(segment)!;
    const totalSpend = custs.reduce((sum, c) => sum + c.monetary, 0);
    return {
      segment,
      count: custs.length,
      avgSpend: custs.length > 0 ? Math.round((totalSpend / custs.length) * 100) / 100 : 0,
      customers: custs.map((c) => ({
        id: c.id,
        name: c.name,
        phone: c.phone,
        rfmScore: `${c.rScore}${c.fScore}${c.mScore}`,
        lastVisit: c.lastVisit,
        totalSpent: Math.round(c.monetary * 100) / 100,
      })),
    };
  });

  return result;
}

function buildEmptySegments(): CustomerSegment[] {
  const segments: CustomerSegment['segment'][] = ['Champions', 'Loyal', 'AtRisk', 'New', 'Dormant'];
  return segments.map((segment) => ({
    segment,
    count: 0,
    avgSpend: 0,
    customers: [],
  }));
}
