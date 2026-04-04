import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';

interface AlertQuery {
  status?: string;
  type?: string;
  severity?: string;
  locationId?: string;
  page: number;
  limit: number;
}

export async function getAlerts(businessId: string, query: AlertQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.status) where.status = query.status;
  if (query.type) where.type = query.type;
  if (query.severity) where.severity = query.severity;
  if (query.locationId) where.locationId = query.locationId;

  const [alerts, total] = await Promise.all([
    prisma.alert.findMany({
      where,
      include: {
        location: { select: { id: true, name: true } },
        operator: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.alert.count({ where }),
  ]);

  return {
    data: alerts,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getAlertById(businessId: string, id: string) {
  const alert = await prisma.alert.findFirst({
    where: { id, businessId },
    include: {
      location: { select: { id: true, name: true } },
      operator: { select: { id: true, name: true } },
    },
  });
  if (!alert) throw new NotFoundError('Alert', id);
  return alert;
}

export async function updateAlertStatus(businessId: string, id: string, status: string) {
  const alert = await prisma.alert.findFirst({ where: { id, businessId } });
  if (!alert) throw new NotFoundError('Alert', id);
  return prisma.alert.update({ where: { id }, data: { status: status as any } });
}

export async function getAlertSummary(businessId: string) {
  const [unread, critical, total] = await Promise.all([
    prisma.alert.count({ where: { businessId, status: 'UNREAD' } }),
    prisma.alert.count({ where: { businessId, severity: 'CRITICAL', status: { in: ['UNREAD', 'READ'] } } }),
    prisma.alert.count({ where: { businessId } }),
  ]);
  return { unread, critical, total };
}

export async function createAlert(
  businessId: string,
  data: {
    type: string;
    severity: string;
    title: string;
    description: string;
    locationId?: string;
    operatorId?: string;
    data?: unknown;
  },
) {
  return prisma.alert.create({
    data: {
      businessId,
      type: data.type as any,
      severity: data.severity as any,
      title: data.title,
      description: data.description,
      locationId: data.locationId,
      operatorId: data.operatorId,
      data: data.data as any,
    },
  });
}
