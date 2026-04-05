import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

interface EstimateItemInput {
  description: string;
  quantity: number;
  unitPrice: number;
  itemId?: string;
}

interface CreateEstimateInput {
  date: string;
  validUntil?: string;
  customerId?: string;
  customerName?: string;
  customerPhone?: string;
  locationId?: string;
  notes?: string;
  termsAndConditions?: string;
  items: EstimateItemInput[];
}

interface UpdateEstimateInput {
  date?: string;
  validUntil?: string;
  customerId?: string;
  customerName?: string;
  customerPhone?: string;
  notes?: string;
  termsAndConditions?: string;
  items?: EstimateItemInput[];
}

interface EstimateFilters {
  status?: string;
  startDate?: string;
  endDate?: string;
  page?: number;
  limit?: number;
}

function computeEstimateTotals(items: EstimateItemInput[]) {
  const subtotal = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  // Assume standard 9% CGST + 9% SGST = 18% GST
  const cgstAmount = Math.round(subtotal * 0.09 * 100) / 100;
  const sgstAmount = Math.round(subtotal * 0.09 * 100) / 100;
  const total = Math.round((subtotal + cgstAmount + sgstAmount) * 100) / 100;
  return { subtotal, cgstAmount, sgstAmount, total };
}

export async function createEstimate(businessId: string, createdById: string, data: CreateEstimateInput) {
  if (data.items.length === 0) {
    throw new BadRequestError('At least one item is required');
  }

  const totals = computeEstimateTotals(data.items);

  return prisma.estimate.create({
    data: {
      date: new Date(data.date),
      validUntil: data.validUntil ? new Date(data.validUntil) : null,
      status: 'ESTIMATE_DRAFT',
      subtotal: totals.subtotal,
      cgstAmount: totals.cgstAmount,
      sgstAmount: totals.sgstAmount,
      total: totals.total,
      notes: data.notes,
      termsAndConditions: data.termsAndConditions,
      businessId,
      customerId: data.customerId,
      customerName: data.customerName,
      customerPhone: data.customerPhone,
      locationId: data.locationId,
      createdById,
      items: {
        create: data.items.map((item) => ({
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineTotal: item.quantity * item.unitPrice,
          itemId: item.itemId,
        })),
      },
    },
    include: { items: true },
  });
}

export async function updateEstimate(businessId: string, id: string, data: UpdateEstimateInput) {
  const estimate = await prisma.estimate.findFirst({
    where: { id, businessId },
  });

  if (!estimate) {
    throw new NotFoundError('Estimate', id);
  }

  if (estimate.status !== 'ESTIMATE_DRAFT') {
    throw new BadRequestError('Only draft estimates can be updated');
  }

  return prisma.$transaction(async (tx) => {
    if (data.items) {
      if (data.items.length === 0) {
        throw new BadRequestError('At least one item is required');
      }

      await tx.estimateItem.deleteMany({ where: { estimateId: id } });

      await tx.estimateItem.createMany({
        data: data.items.map((item) => ({
          estimateId: id,
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineTotal: item.quantity * item.unitPrice,
          itemId: item.itemId,
        })),
      });
    }

    const totals = data.items ? computeEstimateTotals(data.items) : {};

    return tx.estimate.update({
      where: { id },
      data: {
        ...(data.date !== undefined && { date: new Date(data.date) }),
        ...(data.validUntil !== undefined && { validUntil: data.validUntil ? new Date(data.validUntil) : null }),
        ...(data.customerId !== undefined && { customerId: data.customerId }),
        ...(data.customerName !== undefined && { customerName: data.customerName }),
        ...(data.customerPhone !== undefined && { customerPhone: data.customerPhone }),
        ...(data.notes !== undefined && { notes: data.notes }),
        ...(data.termsAndConditions !== undefined && { termsAndConditions: data.termsAndConditions }),
        ...totals,
      },
      include: { items: true },
    });
  });
}

export async function getEstimates(businessId: string, filters: EstimateFilters) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Record<string, unknown> = { businessId };

  if (filters.status) {
    where.status = filters.status;
  }
  if (filters.startDate || filters.endDate) {
    const dateFilter: Record<string, Date> = {};
    if (filters.startDate) dateFilter.gte = new Date(filters.startDate);
    if (filters.endDate) dateFilter.lte = new Date(filters.endDate);
    where.date = dateFilter;
  }

  const [estimates, total] = await Promise.all([
    prisma.estimate.findMany({
      where,
      include: { items: true },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.estimate.count({ where }),
  ]);

  return {
    data: estimates,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };
}

export async function getEstimate(businessId: string, id: string) {
  const estimate = await prisma.estimate.findFirst({
    where: { id, businessId },
    include: { items: true },
  });

  if (!estimate) {
    throw new NotFoundError('Estimate', id);
  }

  return estimate;
}

export async function sendEstimate(businessId: string, id: string) {
  const estimate = await prisma.estimate.findFirst({
    where: { id, businessId },
  });

  if (!estimate) {
    throw new NotFoundError('Estimate', id);
  }

  if (estimate.status !== 'ESTIMATE_DRAFT') {
    throw new BadRequestError('Only draft estimates can be sent');
  }

  return prisma.estimate.update({
    where: { id },
    data: { status: 'ESTIMATE_SENT' },
    include: { items: true },
  });
}

export async function convertToInvoice(
  businessId: string,
  id: string,
  userId: string,
  locationId: string,
) {
  const estimate = await prisma.estimate.findFirst({
    where: { id, businessId },
    include: { items: true },
  });

  if (!estimate) {
    throw new NotFoundError('Estimate', id);
  }

  if (estimate.status === 'ESTIMATE_CONVERTED') {
    throw new BadRequestError('Estimate has already been converted to an invoice');
  }

  if (estimate.status === 'ESTIMATE_REJECTED' || estimate.status === 'ESTIMATE_EXPIRED') {
    throw new BadRequestError(`Cannot convert an estimate with status '${estimate.status}'`);
  }

  return prisma.$transaction(async (tx) => {
    const bill = await tx.bill.create({
      data: {
        date: new Date(),
        subtotal: estimate.subtotal,
        cgstAmount: estimate.cgstAmount,
        sgstAmount: estimate.sgstAmount,
        total: estimate.total,
        netRevenue: estimate.total,
        businessId,
        locationId,
        operatorId: userId,
        customerId: estimate.customerId,
        customerName: estimate.customerName,
        customerPhone: estimate.customerPhone,
        notes: `Converted from estimate #${estimate.estimateNumber}`,
        items: {
          create: estimate.items
            .filter((item) => item.itemId != null)
            .map((item) => ({
              itemId: item.itemId!,
              quantity: Math.round(item.quantity),
              unitPrice: item.unitPrice,
              lineTotal: item.lineTotal,
            })),
        },
      },
      include: { items: true },
    });

    const updatedEstimate = await tx.estimate.update({
      where: { id },
      data: {
        status: 'ESTIMATE_CONVERTED',
        convertedBillId: bill.id,
      },
      include: { items: true },
    });

    return { estimate: updatedEstimate, bill };
  });
}

export async function expireOldEstimates(businessId: string) {
  const now = new Date();

  const result = await prisma.estimate.updateMany({
    where: {
      businessId,
      status: 'ESTIMATE_SENT',
      validUntil: { lt: now },
    },
    data: { status: 'ESTIMATE_EXPIRED' },
  });

  return { expiredCount: result.count };
}
