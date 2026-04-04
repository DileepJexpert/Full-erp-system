import { prisma } from '../../lib/prisma.js';
import { PERFORMANCE_WEIGHTS } from '../../config/constants.js';

interface PerformanceScore {
  operatorId: string;
  operatorName: string;
  locationName: string;
  wastageScore: number;
  revenueScore: number;
  attendanceScore: number;
  cashAccuracyScore: number;
  timelinessScore: number;
  alertScore: number;
  totalScore: number;
  rank: number;
}

export async function computePerformanceScores(
  businessId: string,
  startDate: Date,
  endDate: Date,
): Promise<PerformanceScore[]> {
  const operators = await prisma.user.findMany({
    where: { businessId, role: 'STAFF', isActive: true },
    include: { assignedLocation: true },
  });

  if (operators.length === 0) return [];

  // Gather fleet-wide stats
  const allRecons = await prisma.reconciliation.findMany({
    where: { businessId, date: { gte: startDate, lte: endDate } },
    include: { items: true },
  });

  const allBills = await prisma.bill.findMany({
    where: { businessId, date: { gte: startDate, lte: endDate } },
  });

  const allAttendance = await prisma.attendance.findMany({
    where: { businessId, date: { gte: startDate, lte: endDate } },
  });

  const allCash = await prisma.cashCollection.findMany({
    where: { businessId, date: { gte: startDate, lte: endDate } },
  });

  const allAlerts = await prisma.alert.findMany({
    where: { businessId, createdAt: { gte: startDate, lte: endDate } },
  });

  // Fleet averages
  const fleetWastageRates: number[] = [];
  const fleetRevenues: number[] = [];
  const fleetAttendanceRates: number[] = [];
  const fleetCashAccuracy: number[] = [];

  const totalDays = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));

  const scores: PerformanceScore[] = [];

  for (const op of operators) {
    // Wastage score
    const opRecons = allRecons.filter((r) => r.operatorId === op.id);
    let opDispatched = 0;
    let opWasted = 0;
    for (const r of opRecons) {
      for (const item of r.items) {
        opDispatched += item.dispatched;
        opWasted += item.wasted;
      }
    }
    const wastageRate = opDispatched > 0 ? opWasted / opDispatched : 0;
    fleetWastageRates.push(wastageRate);

    // Revenue score
    const locId = op.assignedLocation?.id;
    const opBills = locId ? allBills.filter((b) => b.locationId === locId) : [];
    const opRevenue = opBills.reduce((s, b) => s + b.total, 0);
    fleetRevenues.push(opRevenue);

    // Attendance score
    const opAttendance = allAttendance.filter((a) => a.operatorId === op.id);
    const attendanceRate = totalDays > 0 ? opAttendance.length / totalDays : 0;
    fleetAttendanceRates.push(attendanceRate);

    // Cash accuracy score
    const opCash = allCash.filter((c) => c.operatorId === op.id);
    const totalExpected = opCash.reduce((s, c) => s + c.expectedCash, 0);
    const totalShortage = opCash.reduce((s, c) => s + c.shortage, 0);
    const cashAccuracy = totalExpected > 0 ? 1 - totalShortage / totalExpected : 1;
    fleetCashAccuracy.push(cashAccuracy);

    // Timeliness score (recon before 10 PM)
    const onTimeRecons = opRecons.filter((r) => r.createdAt.getHours() < 22).length;
    const timelinessRate = opRecons.length > 0 ? onTimeRecons / opRecons.length : 1;

    // Alert score (fewer alerts = better)
    const opAlerts = allAlerts.filter((a) => a.operatorId === op.id).length;

    scores.push({
      operatorId: op.id,
      operatorName: op.name,
      locationName: op.assignedLocation?.name ?? 'Unassigned',
      wastageRate,
      opRevenue,
      attendanceRate,
      cashAccuracy,
      timelinessRate,
      opAlerts,
    } as any);
  }

  // Normalize scores 0-100 relative to fleet
  const avgWastage = avg(fleetWastageRates);
  const maxRevenue = Math.max(...fleetRevenues, 1);
  const avgAttendance = avg(fleetAttendanceRates);
  const avgCash = avg(fleetCashAccuracy);

  const finalScores: PerformanceScore[] = scores.map((s: any) => {
    const wastageScore = clamp(avgWastage > 0 ? (1 - s.wastageRate / (avgWastage * 2)) * 100 : 100);
    const revenueScore = clamp((s.opRevenue / maxRevenue) * 100);
    const attendanceScore = clamp((s.attendanceRate / Math.max(avgAttendance, 0.01)) * 50 + 50);
    const cashAccuracyScore = clamp(s.cashAccuracy * 100);
    const timelinessScore = clamp(s.timelinessRate * 100);
    const alertScore = clamp(Math.max(0, 100 - s.opAlerts * 20));

    const totalScore = Math.round(
      wastageScore * PERFORMANCE_WEIGHTS.wastage +
      revenueScore * PERFORMANCE_WEIGHTS.revenue +
      attendanceScore * PERFORMANCE_WEIGHTS.attendance +
      cashAccuracyScore * PERFORMANCE_WEIGHTS.cashAccuracy +
      timelinessScore * PERFORMANCE_WEIGHTS.timeliness +
      alertScore * PERFORMANCE_WEIGHTS.alerts,
    );

    return {
      operatorId: s.operatorId,
      operatorName: s.operatorName,
      locationName: s.locationName,
      wastageScore: Math.round(wastageScore),
      revenueScore: Math.round(revenueScore),
      attendanceScore: Math.round(attendanceScore),
      cashAccuracyScore: Math.round(cashAccuracyScore),
      timelinessScore: Math.round(timelinessScore),
      alertScore: Math.round(alertScore),
      totalScore,
      rank: 0,
    };
  });

  // Assign ranks
  finalScores.sort((a, b) => b.totalScore - a.totalScore);
  finalScores.forEach((s, i) => { s.rank = i + 1; });

  return finalScores;
}

function avg(nums: number[]): number {
  return nums.length > 0 ? nums.reduce((a, b) => a + b, 0) / nums.length : 0;
}

function clamp(value: number, min = 0, max = 100): number {
  return Math.max(min, Math.min(max, value));
}
