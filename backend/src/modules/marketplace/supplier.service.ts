import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError, ForbiddenError } from '../../utils/errors.js';

// Valid status transitions for marketplace orders
const STATUS_TRANSITIONS: Record<string, string[]> = {
  PENDING: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['SHIPPED', 'CANCELLED'],
  SHIPPED: ['DELIVERED'],
  DELIVERED: [],
  CANCELLED: [],
};

export async function updateOrderStatus(
  supplierId: string,
  orderId: string,
  newStatus: string,
) {
  const order = await prisma.marketplaceOrder.findFirst({
    where: { id: orderId, supplierId },
  });

  if (!order) {
    throw new NotFoundError('MarketplaceOrder', orderId);
  }

  const allowedTransitions = STATUS_TRANSITIONS[order.status];
  if (!allowedTransitions || !allowedTransitions.includes(newStatus)) {
    throw new BadRequestError(
      `Cannot transition order from "${order.status}" to "${newStatus}". ` +
        `Allowed transitions: ${allowedTransitions?.join(', ') || 'none'}`,
    );
  }

  const updated = await prisma.marketplaceOrder.update({
    where: { id: orderId },
    data: {
      status: newStatus as any,
      ...(newStatus === 'DELIVERED' && { deliveryDate: new Date() }),
    },
    include: {
      items: true,
    },
  });

  return updated;
}

export async function updateSupplierRating(supplierId: string) {
  const agg = await prisma.supplierRating.aggregate({
    where: { supplierId },
    _avg: { rating: true },
    _count: true,
  });

  const avgRating = agg._avg.rating ?? 0;

  await prisma.supplierProfile.update({
    where: { id: supplierId },
    data: {
      rating: Math.round(avgRating * 100) / 100,
    },
  });

  return {
    supplierId,
    averageRating: Math.round(avgRating * 100) / 100,
    totalRatings: agg._count,
  };
}
