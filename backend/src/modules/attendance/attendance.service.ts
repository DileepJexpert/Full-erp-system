import { prisma } from '../../lib/prisma.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import { checkProximity } from '../../utils/haversine.js';
import type { CheckInInput, AttendanceQuery } from './attendance.schema.js';

export async function checkIn(businessId: string, operatorId: string, input: CheckInInput) {
  // Fetch location to verify it belongs to this business
  const location = await prisma.location.findFirst({
    where: { id: input.locationId, businessId },
  });
  if (!location) throw new NotFoundError('Location', input.locationId);

  // GPS proximity check if both location and input have coordinates
  if (
    location.latitude != null &&
    location.longitude != null &&
    input.checkInLat != null &&
    input.checkInLng != null
  ) {
    const result = checkProximity(
      input.checkInLat,
      input.checkInLng,
      location.latitude,
      location.longitude,
    );
    if (!result.withinRange) {
      throw new BadRequestError(
        `You are ${result.distance}m away from the location. Must be within 200m to check in.`,
      );
    }
  }

  const attendance = await prisma.attendance.create({
    data: {
      businessId,
      operatorId,
      locationId: input.locationId,
      date: new Date(input.date),
      checkInTime: new Date(),
      checkInLat: input.checkInLat,
      checkInLng: input.checkInLng,
      isSubstitute: input.isSubstitute,
      status: 'PRESENT',
    },
    include: {
      operator: { select: { id: true, name: true } },
      location: { select: { id: true, name: true } },
    },
  });

  eventBus.emit(EVENTS.ATTENDANCE_CHECKED_IN, {
    attendanceId: attendance.id,
    businessId,
    operatorId,
    locationId: input.locationId,
  });

  return attendance;
}

export async function checkOut(businessId: string, attendanceId: string) {
  const attendance = await prisma.attendance.findFirst({
    where: { id: attendanceId, businessId },
  });
  if (!attendance) throw new NotFoundError('Attendance', attendanceId);
  if (attendance.checkOutTime) throw new BadRequestError('Already checked out');

  const checkOutTime = new Date();
  const diffMs = checkOutTime.getTime() - attendance.checkInTime.getTime();
  const hoursWorked = Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100;

  const updated = await prisma.attendance.update({
    where: { id: attendanceId },
    data: { checkOutTime, hoursWorked },
    include: {
      operator: { select: { id: true, name: true } },
      location: { select: { id: true, name: true } },
    },
  });

  return updated;
}

export async function getAttendance(businessId: string, query: AttendanceQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.locationId) where.locationId = query.locationId;
  if (query.operatorId) where.operatorId = query.operatorId;
  if (query.startDate || query.endDate) {
    where.date = {} as Record<string, Date>;
    if (query.startDate) (where.date as any).gte = new Date(query.startDate);
    if (query.endDate) (where.date as any).lte = new Date(query.endDate);
  }

  const [data, total] = await Promise.all([
    prisma.attendance.findMany({
      where,
      include: {
        operator: { select: { id: true, name: true } },
        location: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.attendance.count({ where }),
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

export async function getAttendanceById(businessId: string, id: string) {
  const attendance = await prisma.attendance.findFirst({
    where: { id, businessId },
    include: {
      operator: { select: { id: true, name: true } },
      location: { select: { id: true, name: true } },
    },
  });
  if (!attendance) throw new NotFoundError('Attendance', id);
  return attendance;
}
