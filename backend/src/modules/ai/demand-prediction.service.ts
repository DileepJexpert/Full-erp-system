import { prisma } from '../../lib/prisma.js';
import { claude } from '../../lib/claude.js';

interface PredictionResult {
  qty: number;
  confidence: number;
  reasoning: string;
}

/**
 * Calculate day-of-week averages from sales data.
 */
function calculateDayOfWeekAvg(
  salesByDate: Map<string, number>,
): Record<string, number> {
  const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const daySums: Record<string, { total: number; count: number }> = {};

  for (const [dateStr, qty] of salesByDate) {
    const day = dayNames[new Date(dateStr).getDay()];
    if (!daySums[day]) daySums[day] = { total: 0, count: 0 };
    daySums[day].total += qty;
    daySums[day].count += 1;
  }

  const avgs: Record<string, number> = {};
  for (const [day, { total, count }] of Object.entries(daySums)) {
    avgs[day] = count > 0 ? Math.round((total / count) * 10) / 10 : 0;
  }

  return avgs;
}

/**
 * Calculate linear trend (slope) from time-series sales data.
 * Positive = growing, negative = declining.
 */
function calculateTrend(salesByDate: Map<string, number>): number {
  const entries = Array.from(salesByDate.entries())
    .sort(([a], [b]) => a.localeCompare(b));

  if (entries.length < 2) return 0;

  const n = entries.length;
  const xMean = (n - 1) / 2;
  const yMean = entries.reduce((s, [, v]) => s + v, 0) / n;

  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < n; i++) {
    numerator += (i - xMean) * (entries[i][1] - yMean);
    denominator += (i - xMean) ** 2;
  }

  return denominator === 0 ? 0 : Math.round((numerator / denominator) * 100) / 100;
}

/**
 * Predict demand for a specific item at a location on a given date.
 *
 * Steps:
 * 1. Gather 90-day sales history for item + location
 * 2. Calculate overall avg, day-of-week avg, trend
 * 3. Query Claude with structured data for refined prediction
 * 4. Store in DemandPrediction table
 */
export async function predictDemand(
  businessId: string,
  userId: string,
  itemId: string,
  locationId: string,
  targetDate: string,
): Promise<PredictionResult> {
  const target = new Date(targetDate);
  const ninetyDaysAgo = new Date(target);
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

  // Fetch item info
  const item = await prisma.item.findFirst({
    where: { id: itemId, businessId },
    select: { name: true, category: true },
  });

  if (!item) {
    throw new Error(`Item ${itemId} not found`);
  }

  // Gather 90-day sales history for this item at this location
  const billItems = await prisma.billItem.findMany({
    where: {
      itemId,
      bill: {
        businessId,
        locationId,
        date: { gte: ninetyDaysAgo, lte: target },
      },
    },
    include: {
      bill: { select: { date: true } },
    },
  });

  // Aggregate by date
  const salesByDate = new Map<string, number>();
  for (const bi of billItems) {
    const dateStr = (bi as any).bill.date.toISOString().split('T')[0];
    salesByDate.set(dateStr, (salesByDate.get(dateStr) ?? 0) + bi.quantity);
  }

  const totalDays = salesByDate.size;
  const totalQty = Array.from(salesByDate.values()).reduce((s, v) => s + v, 0);
  const overallAvg = totalDays > 0 ? Math.round((totalQty / totalDays) * 10) / 10 : 0;

  const dayOfWeekAvg = calculateDayOfWeekAvg(salesByDate);
  const trend = calculateTrend(salesByDate);

  const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const targetDayName = dayNames[target.getDay()];
  const targetDayAvg = dayOfWeekAvg[targetDayName] ?? overallAvg;

  // If we have very little data, return a simple statistical estimate
  if (totalDays < 7) {
    const qty = Math.max(1, Math.round(overallAvg));
    const result: PredictionResult = {
      qty,
      confidence: 0.3,
      reasoning: `Insufficient data (${totalDays} days). Using simple average: ${overallAvg}.`,
    };

    await storePrediction(businessId, itemId, locationId, targetDate, result, { overallAvg, totalDays });
    return result;
  }

  // Build prompt for Claude
  const prompt = [
    `Predict the demand quantity for "${item.name}" (category: ${item.category ?? 'N/A'}) at a food business location.`,
    ``,
    `Target date: ${targetDate} (${targetDayName})`,
    ``,
    `90-day sales data:`,
    `- Total days with sales: ${totalDays}`,
    `- Overall daily average: ${overallAvg}`,
    `- Day-of-week averages: ${JSON.stringify(dayOfWeekAvg)}`,
    `- Trend slope: ${trend} (positive = growing, negative = declining)`,
    `- ${targetDayName} average: ${targetDayAvg}`,
    `- Last 7 days: ${Array.from(salesByDate.entries()).sort(([a], [b]) => b.localeCompare(a)).slice(0, 7).map(([d, q]) => `${d}: ${q}`).join(', ')}`,
    ``,
    `Respond in exactly this JSON format (no other text):`,
    `{"qty": <integer>, "confidence": <0.0-1.0>, "reasoning": "<one sentence>"}`,
  ].join('\n');

  try {
    const { text, tokensUsed } = await claude.query(prompt, {
      maxTokens: 256,
      system: 'You are a demand forecasting model. Return only valid JSON, nothing else.',
    });

    // Parse Claude's response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('Claude did not return valid JSON');
    }

    const parsed = JSON.parse(jsonMatch[0]) as PredictionResult;
    const qty = Math.max(0, Math.round(parsed.qty));
    const confidence = Math.max(0, Math.min(1, parsed.confidence));

    const result: PredictionResult = {
      qty,
      confidence,
      reasoning: parsed.reasoning,
    };

    // Log query
    await prisma.aIQueryLog.create({
      data: {
        type: 'DEMAND_PREDICTION',
        query: `Predict demand for ${item.name} at ${locationId} on ${targetDate}`,
        context: { overallAvg, dayOfWeekAvg, trend, targetDayAvg },
        response: text,
        model: 'claude-haiku',
        tokensUsed,
        latencyMs: 0,
        userId,
        businessId,
      },
    });

    await storePrediction(businessId, itemId, locationId, targetDate, result, {
      overallAvg,
      dayOfWeekAvg,
      trend,
      targetDayAvg,
    });

    return result;
  } catch (error) {
    // Fallback to statistical prediction
    const qty = Math.max(1, Math.round(targetDayAvg + trend));
    const result: PredictionResult = {
      qty,
      confidence: 0.5,
      reasoning: `Statistical estimate based on ${targetDayName} average (${targetDayAvg}) with trend adjustment (${trend}).`,
    };

    await storePrediction(businessId, itemId, locationId, targetDate, result, {
      overallAvg,
      dayOfWeekAvg,
      trend,
      fallbackReason: error instanceof Error ? error.message : 'Unknown error',
    });

    return result;
  }
}

/**
 * Store prediction in DemandPrediction table.
 */
async function storePrediction(
  businessId: string,
  itemId: string,
  locationId: string,
  targetDate: string,
  result: PredictionResult,
  factors: Record<string, unknown>,
): Promise<void> {
  await prisma.demandPrediction.upsert({
    where: {
      itemId_locationId_date: {
        itemId,
        locationId,
        date: new Date(targetDate),
      },
    },
    create: {
      itemId,
      locationId,
      date: new Date(targetDate),
      predictedQty: result.qty,
      confidence: result.confidence,
      factors: { ...factors, reasoning: result.reasoning },
      businessId,
    },
    update: {
      predictedQty: result.qty,
      confidence: result.confidence,
      factors: { ...factors, reasoning: result.reasoning },
    },
  });
}
