import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

/** Annual leave entitlements per type. */
const ANNUAL_ENTITLEMENT: Record<string, number> = {
  CASUAL: 12,
  SICK: 6,
  EARNED: 15,
  UNPAID: 365, // unlimited effectively
};

/**
 * Calculate number of days between two dates (inclusive).
 */
export function calculateDays(startDate: Date, endDate: Date): number {
  const msPerDay = 86_400_000;
  const diff = Math.floor((endDate.getTime() - startDate.getTime()) / msPerDay) + 1;
  if (diff < 1) throw new BadRequestError('endDate must be on or after startDate');
  return diff;
}

/**
 * Create a leave request.
 */
export async function createLeaveRequest(
  businessId: string,
  userId: string,
  input: { type: string; startDate: string; endDate: string; reason?: string },
) {
  const start = new Date(input.startDate);
  const end = new Date(input.endDate);
  const days = calculateDays(start, end);

  return prisma.leaveRequest.create({
    data: {
      type: input.type as any,
      startDate: start,
      endDate: end,
      days,
      reason: input.reason ?? null,
      userId,
      businessId,
    },
  });
}

/**
 * List leave requests. Staff sees own, Manager/Owner sees all.
 */
export async function listLeaveRequests(
  businessId: string,
  userId: string,
  role: string,
  filters: { status?: string; userId?: string; limit?: number; offset?: number },
) {
  const where: Record<string, unknown> = { businessId };

  if (role === 'STAFF') {
    where.userId = userId;
  } else if (filters.userId) {
    where.userId = filters.userId;
  }

  if (filters.status) where.status = filters.status;

  const [data, total] = await Promise.all([
    prisma.leaveRequest.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: filters.limit ?? 50,
      skip: filters.offset ?? 0,
    }),
    prisma.leaveRequest.count({ where }),
  ]);

  return { data, total };
}

/**
 * Approve a leave request.
 */
export async function approveLeave(businessId: string, leaveId: string, approvedBy: string) {
  const leave = await prisma.leaveRequest.findFirst({
    where: { id: leaveId, businessId },
  });

  if (!leave) throw new NotFoundError('LeaveRequest', leaveId);
  if (leave.status !== 'LEAVE_PENDING') {
    throw new BadRequestError(`Cannot approve a leave that is ${leave.status}`);
  }

  return prisma.leaveRequest.update({
    where: { id: leaveId },
    data: { status: 'LEAVE_APPROVED', approvedBy },
  });
}

/**
 * Reject a leave request.
 */
export async function rejectLeave(businessId: string, leaveId: string) {
  const leave = await prisma.leaveRequest.findFirst({
    where: { id: leaveId, businessId },
  });

  if (!leave) throw new NotFoundError('LeaveRequest', leaveId);
  if (leave.status !== 'LEAVE_PENDING') {
    throw new BadRequestError(`Cannot reject a leave that is ${leave.status}`);
  }

  return prisma.leaveRequest.update({
    where: { id: leaveId },
    data: { status: 'LEAVE_REJECTED' },
  });
}

/**
 * Get leave balance for a user in the current year.
 * Balance = annual entitlement - approved days used this year.
 */
export async function getLeaveBalance(businessId: string, targetUserId: string) {
  const now = new Date();
  const yearStart = new Date(now.getFullYear(), 0, 1);
  const yearEnd = new Date(now.getFullYear(), 11, 31, 23, 59, 59);

  const approved = await prisma.leaveRequest.findMany({
    where: {
      businessId,
      userId: targetUserId,
      status: 'LEAVE_APPROVED',
      startDate: { gte: yearStart },
      endDate: { lte: yearEnd },
    },
    select: { type: true, days: true },
  });

  const usedByType: Record<string, number> = {};
  for (const req of approved) {
    usedByType[req.type] = (usedByType[req.type] ?? 0) + req.days;
  }

  const balance = Object.entries(ANNUAL_ENTITLEMENT).map(([type, entitlement]) => ({
    type,
    entitlement,
    used: usedByType[type] ?? 0,
    remaining: entitlement - (usedByType[type] ?? 0),
  }));

  return { userId: targetUserId, year: now.getFullYear(), balance };
}
