import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

const VALID_STATUS_TRANSITIONS: Record<string, string[]> = {
  APPT_BOOKED: ['APPT_CONFIRMED', 'APPT_CANCELLED', 'APPT_NO_SHOW'],
  APPT_CONFIRMED: ['APPT_IN_PROGRESS', 'APPT_CANCELLED', 'APPT_NO_SHOW'],
  APPT_IN_PROGRESS: ['APPT_COMPLETED', 'APPT_CANCELLED'],
  APPT_COMPLETED: [],
  APPT_CANCELLED: [],
  APPT_NO_SHOW: [],
};

// Business hours: 9AM to 9PM, 30-minute slot granularity
const BUSINESS_START_HOUR = 9;
const BUSINESS_END_HOUR = 21;
const SLOT_DURATION_MINUTES = 30;

interface CreateAppointmentData {
  date: string;
  startTime: string;
  endTime: string;
  serviceName: string;
  amount?: number;
  notes?: string;
  locationId: string;
  customerId?: string;
  customerName: string;
  customerPhone: string;
  assignedToId?: string;
  createdById: string;
}

interface UpdateAppointmentData {
  date?: string;
  startTime?: string;
  endTime?: string;
  serviceName?: string;
  amount?: number;
  notes?: string;
  locationId?: string;
  customerName?: string;
  customerPhone?: string;
  assignedToId?: string;
}

interface AppointmentFilters {
  startDate?: string;
  endDate?: string;
  locationId?: string;
  status?: string;
  assignedToId?: string;
  page?: number;
  limit?: number;
}

function timeToMinutes(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

function minutesToTime(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
}

async function checkTimeConflict(
  businessId: string,
  locationId: string,
  date: string,
  startTime: string,
  endTime: string,
  assignedToId?: string,
  excludeId?: string,
): Promise<void> {
  const where: Record<string, unknown> = {
    businessId,
    locationId,
    date: new Date(date),
    status: { notIn: ['APPT_CANCELLED', 'APPT_NO_SHOW'] },
  };

  if (assignedToId) {
    where.assignedToId = assignedToId;
  }

  if (excludeId) {
    where.id = { not: excludeId };
  }

  const existing = await prisma.appointment.findMany({ where });

  const newStart = timeToMinutes(startTime);
  const newEnd = timeToMinutes(endTime);

  for (const appt of existing) {
    const existStart = timeToMinutes(appt.startTime);
    const existEnd = timeToMinutes(appt.endTime);

    if (newStart < existEnd && newEnd > existStart) {
      throw new BadRequestError(
        `Time slot conflicts with existing appointment (${appt.startTime}-${appt.endTime} for ${appt.serviceName})`,
      );
    }
  }
}

export async function createAppointment(businessId: string, data: CreateAppointmentData) {
  if (timeToMinutes(data.startTime) >= timeToMinutes(data.endTime)) {
    throw new BadRequestError('Start time must be before end time');
  }

  await checkTimeConflict(
    businessId,
    data.locationId,
    data.date,
    data.startTime,
    data.endTime,
    data.assignedToId,
  );

  return prisma.appointment.create({
    data: {
      date: new Date(data.date),
      startTime: data.startTime,
      endTime: data.endTime,
      serviceName: data.serviceName,
      amount: data.amount,
      notes: data.notes,
      businessId,
      locationId: data.locationId,
      customerId: data.customerId,
      customerName: data.customerName,
      customerPhone: data.customerPhone,
      assignedToId: data.assignedToId,
      createdById: data.createdById,
    },
  });
}

export async function updateAppointment(businessId: string, id: string, data: UpdateAppointmentData) {
  const appointment = await prisma.appointment.findFirst({
    where: { id, businessId },
  });
  if (!appointment) throw new NotFoundError('Appointment', id);

  if (appointment.status === 'APPT_COMPLETED' || appointment.status === 'APPT_CANCELLED') {
    throw new BadRequestError('Cannot update a completed or cancelled appointment');
  }

  const locationId = data.locationId ?? appointment.locationId;
  const date = data.date ?? appointment.date.toISOString().split('T')[0];
  const startTime = data.startTime ?? appointment.startTime;
  const endTime = data.endTime ?? appointment.endTime;
  const assignedToId = data.assignedToId !== undefined ? data.assignedToId : appointment.assignedToId;

  if (timeToMinutes(startTime) >= timeToMinutes(endTime)) {
    throw new BadRequestError('Start time must be before end time');
  }

  if (data.date || data.startTime || data.endTime || data.locationId || data.assignedToId) {
    await checkTimeConflict(
      businessId,
      locationId,
      date,
      startTime,
      endTime,
      assignedToId ?? undefined,
      id,
    );
  }

  return prisma.appointment.update({
    where: { id },
    data: {
      ...(data.date && { date: new Date(data.date) }),
      ...(data.startTime && { startTime: data.startTime }),
      ...(data.endTime && { endTime: data.endTime }),
      ...(data.serviceName && { serviceName: data.serviceName }),
      ...(data.amount !== undefined && { amount: data.amount }),
      ...(data.notes !== undefined && { notes: data.notes }),
      ...(data.locationId && { locationId: data.locationId }),
      ...(data.customerName && { customerName: data.customerName }),
      ...(data.customerPhone && { customerPhone: data.customerPhone }),
      ...(data.assignedToId !== undefined && { assignedToId: data.assignedToId }),
    },
  });
}

export async function getAppointments(businessId: string, filters: AppointmentFilters) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 50;
  const skip = (page - 1) * limit;

  const where: Record<string, unknown> = { businessId };

  if (filters.startDate || filters.endDate) {
    where.date = {};
    if (filters.startDate) (where.date as Record<string, unknown>).gte = new Date(filters.startDate);
    if (filters.endDate) (where.date as Record<string, unknown>).lte = new Date(filters.endDate);
  }

  if (filters.locationId) where.locationId = filters.locationId;
  if (filters.status) where.status = filters.status;
  if (filters.assignedToId) where.assignedToId = filters.assignedToId;

  const [data, total] = await Promise.all([
    prisma.appointment.findMany({
      where,
      orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
      skip,
      take: limit,
    }),
    prisma.appointment.count({ where }),
  ]);

  return { data, total, page, limit };
}

export async function getAppointment(businessId: string, id: string) {
  const appointment = await prisma.appointment.findFirst({
    where: { id, businessId },
  });
  if (!appointment) throw new NotFoundError('Appointment', id);
  return appointment;
}

export async function updateStatus(businessId: string, id: string, status: string) {
  const appointment = await prisma.appointment.findFirst({
    where: { id, businessId },
  });
  if (!appointment) throw new NotFoundError('Appointment', id);

  const allowed = VALID_STATUS_TRANSITIONS[appointment.status];
  if (!allowed || !allowed.includes(status)) {
    throw new BadRequestError(
      `Cannot transition from ${appointment.status} to ${status}`,
    );
  }

  return prisma.appointment.update({
    where: { id },
    data: { status: status as any },
  });
}

export async function getTodayAppointments(businessId: string, locationId: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayEnd = new Date(today);
  todayEnd.setHours(23, 59, 59, 999);

  return prisma.appointment.findMany({
    where: {
      businessId,
      locationId,
      date: { gte: today, lte: todayEnd },
    },
    orderBy: { startTime: 'asc' },
  });
}

export async function getAvailableSlots(
  businessId: string,
  locationId: string,
  date: string,
  duration: number,
) {
  if (duration <= 0) throw new BadRequestError('Duration must be positive');

  const booked = await prisma.appointment.findMany({
    where: {
      businessId,
      locationId,
      date: new Date(date),
      status: { notIn: ['APPT_CANCELLED', 'APPT_NO_SHOW'] },
    },
    select: { startTime: true, endTime: true },
  });

  const bookedRanges = booked.map((a) => ({
    start: timeToMinutes(a.startTime),
    end: timeToMinutes(a.endTime),
  }));

  const slots: { startTime: string; endTime: string }[] = [];
  const dayStart = BUSINESS_START_HOUR * 60;
  const dayEnd = BUSINESS_END_HOUR * 60;

  for (let slotStart = dayStart; slotStart + duration <= dayEnd; slotStart += SLOT_DURATION_MINUTES) {
    const slotEnd = slotStart + duration;

    const hasConflict = bookedRanges.some(
      (range) => slotStart < range.end && slotEnd > range.start,
    );

    if (!hasConflict) {
      slots.push({
        startTime: minutesToTime(slotStart),
        endTime: minutesToTime(slotEnd),
      });
    }
  }

  return slots;
}

export async function markNoShow(businessId: string, id: string) {
  const appointment = await prisma.appointment.findFirst({
    where: { id, businessId },
  });
  if (!appointment) throw new NotFoundError('Appointment', id);

  if (appointment.status === 'APPT_COMPLETED' || appointment.status === 'APPT_CANCELLED') {
    throw new BadRequestError('Cannot mark a completed or cancelled appointment as no-show');
  }

  return prisma.appointment.update({
    where: { id },
    data: { status: 'APPT_NO_SHOW' },
  });
}

export async function getDueReminders(businessId: string) {
  const now = new Date();
  const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  return prisma.appointment.findMany({
    where: {
      businessId,
      reminderSent: false,
      status: { in: ['APPT_BOOKED', 'APPT_CONFIRMED'] },
      date: { gte: now, lte: in24Hours },
    },
    orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
  });
}
