import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

interface ReturnItemInput {
  itemId: string;
  quantity: number;
  unitPrice: number;
  isResaleable: boolean;
}

interface CreateReturnInput {
  date: string;
  reason: 'DAMAGED' | 'EXPIRED' | 'WRONG_ITEM' | 'QUALITY_ISSUE' | 'CUSTOMER_CHANGE' | 'OTHER';
  refundMode: 'CASH_REFUND' | 'STORE_CREDIT' | 'EXCHANGE' | 'ORIGINAL_METHOD';
  originalBillId: string;
  locationId: string;
  customerId?: string;
  notes?: string;
  items: ReturnItemInput[];
}

interface ReturnFilters {
  locationId?: string;
  status?: string;
  startDate?: string;
  endDate?: string;
  page?: number;
  limit?: number;
}

export async function createSalesReturn(businessId: string, processedById: string, data: CreateReturnInput) {
  const bill = await prisma.bill.findFirst({
    where: { id: data.originalBillId, businessId },
  });

  if (!bill) {
    throw new NotFoundError('Original bill', data.originalBillId);
  }

  if (data.items.length === 0) {
    throw new BadRequestError('At least one return item is required');
  }

  const subtotal = data.items.reduce((sum, item) => {
    return sum + item.quantity * item.unitPrice;
  }, 0);

  const refundAmount = data.refundMode === 'STORE_CREDIT' ? 0 : subtotal;
  const storeCreditAmount = data.refundMode === 'STORE_CREDIT' ? subtotal : 0;

  return prisma.$transaction(async (tx) => {
    const salesReturn = await tx.salesReturn.create({
      data: {
        date: new Date(data.date),
        reason: data.reason,
        refundMode: data.refundMode,
        status: 'RETURN_PENDING',
        subtotal,
        refundAmount,
        storeCreditAmount,
        notes: data.notes,
        businessId,
        locationId: data.locationId,
        originalBillId: data.originalBillId,
        customerId: data.customerId,
        processedById,
        items: {
          create: data.items.map((item) => ({
            itemId: item.itemId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            lineTotal: item.quantity * item.unitPrice,
            isResaleable: item.isResaleable,
          })),
        },
      },
      include: { items: true },
    });

    // Update stock for resaleable items
    for (const item of data.items) {
      if (item.isResaleable) {
        await tx.item.update({
          where: { id: item.itemId },
          data: { centralStock: { increment: item.quantity } },
        });
      }
    }

    // If store credit, update customer balance
    if (data.refundMode === 'STORE_CREDIT' && data.customerId) {
      await tx.customer.update({
        where: { id: data.customerId },
        data: { storeCreditBalance: { increment: storeCreditAmount } },
      });
    }

    return salesReturn;
  });
}

export async function getSalesReturns(businessId: string, filters: ReturnFilters) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Record<string, unknown> = { businessId };

  if (filters.locationId) {
    where.locationId = filters.locationId;
  }
  if (filters.status) {
    where.status = filters.status;
  }
  if (filters.startDate || filters.endDate) {
    const dateFilter: Record<string, Date> = {};
    if (filters.startDate) dateFilter.gte = new Date(filters.startDate);
    if (filters.endDate) dateFilter.lte = new Date(filters.endDate);
    where.date = dateFilter;
  }

  const [returns, total] = await Promise.all([
    prisma.salesReturn.findMany({
      where,
      include: { items: true },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.salesReturn.count({ where }),
  ]);

  return {
    data: returns,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };
}

export async function getSalesReturn(businessId: string, id: string) {
  const salesReturn = await prisma.salesReturn.findFirst({
    where: { id, businessId },
    include: { items: true },
  });

  if (!salesReturn) {
    throw new NotFoundError('SalesReturn', id);
  }

  return salesReturn;
}

export async function approveSalesReturn(businessId: string, id: string, userId: string) {
  const salesReturn = await prisma.salesReturn.findFirst({
    where: { id, businessId },
    include: { items: true },
  });

  if (!salesReturn) {
    throw new NotFoundError('SalesReturn', id);
  }

  if (salesReturn.status !== 'RETURN_PENDING' && salesReturn.status !== 'RETURN_APPROVED') {
    throw new BadRequestError(`Cannot approve a return with status '${salesReturn.status}'`);
  }

  return prisma.salesReturn.update({
    where: { id },
    data: {
      status: 'RETURN_COMPLETED',
      processedById: userId,
    },
    include: { items: true },
  });
}

export async function rejectSalesReturn(businessId: string, id: string, reason: string) {
  const salesReturn = await prisma.salesReturn.findFirst({
    where: { id, businessId },
  });

  if (!salesReturn) {
    throw new NotFoundError('SalesReturn', id);
  }

  if (salesReturn.status !== 'RETURN_PENDING') {
    throw new BadRequestError(`Cannot reject a return with status '${salesReturn.status}'`);
  }

  return prisma.$transaction(async (tx) => {
    // Reverse stock changes for resaleable items
    const items = await tx.salesReturnItem.findMany({ where: { returnId: id } });
    for (const item of items) {
      if (item.isResaleable) {
        await tx.item.update({
          where: { id: item.itemId },
          data: { centralStock: { decrement: item.quantity } },
        });
      }
    }

    // Reverse store credit if applicable
    if (salesReturn.refundMode === 'STORE_CREDIT' && salesReturn.customerId && salesReturn.storeCreditAmount > 0) {
      await tx.customer.update({
        where: { id: salesReturn.customerId },
        data: { storeCreditBalance: { decrement: salesReturn.storeCreditAmount } },
      });
    }

    return tx.salesReturn.update({
      where: { id },
      data: {
        status: 'RETURN_REJECTED',
        notes: reason ? `${salesReturn.notes ?? ''}\nRejection reason: ${reason}`.trim() : salesReturn.notes,
      },
      include: { items: true },
    });
  });
}
