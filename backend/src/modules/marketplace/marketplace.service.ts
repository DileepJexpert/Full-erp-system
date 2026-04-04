import { prisma } from '../../lib/prisma.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';

const MARKETPLACE_COMMISSION_PCT = 5; // 5% commission

interface ListingFilters {
  category?: string;
  city?: string;
  minPrice?: number;
  maxPrice?: number;
  search?: string;
  page?: number;
  limit?: number;
}

interface OrderItemInput {
  listingId: string;
  quantity: number;
}

export async function searchListings(filters: ListingFilters) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Record<string, unknown> = {
    isActive: true,
  };

  if (filters.category) {
    where.category = filters.category;
  }

  if (filters.city) {
    where.supplier = { city: filters.city, isActive: true };
  } else {
    where.supplier = { isActive: true };
  }

  if (filters.minPrice !== undefined || filters.maxPrice !== undefined) {
    where.pricePerUnit = {};
    if (filters.minPrice !== undefined) {
      (where.pricePerUnit as Record<string, number>).gte = filters.minPrice;
    }
    if (filters.maxPrice !== undefined) {
      (where.pricePerUnit as Record<string, number>).lte = filters.maxPrice;
    }
  }

  if (filters.search) {
    where.OR = [
      { name: { contains: filters.search, mode: 'insensitive' } },
      { description: { contains: filters.search, mode: 'insensitive' } },
    ];
  }

  const [listings, total] = await Promise.all([
    prisma.supplierListing.findMany({
      where,
      skip,
      take: limit,
      include: {
        supplier: {
          select: {
            id: true,
            businessName: true,
            city: true,
            rating: true,
            isVerified: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    }),
    prisma.supplierListing.count({ where }),
  ]);

  return {
    data: listings,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}

export async function createOrder(
  businessId: string,
  supplierId: string,
  items: OrderItemInput[],
) {
  if (!items.length) {
    throw new BadRequestError('Order must have at least one item');
  }

  // Verify supplier exists and is active
  const supplier = await prisma.supplierProfile.findUnique({
    where: { id: supplierId },
  });
  if (!supplier || !supplier.isActive) {
    throw new NotFoundError('SupplierProfile', supplierId);
  }

  // Fetch all listings and validate they belong to this supplier
  const listingIds = items.map((i) => i.listingId);
  const listings = await prisma.supplierListing.findMany({
    where: {
      id: { in: listingIds },
      supplierId,
      isActive: true,
    },
  });

  const listingMap = new Map(listings.map((l) => [l.id, l]));

  // Validate all items and calculate totals
  const orderItems: Array<{
    listingId: string;
    quantity: number;
    unitPrice: number;
    lineTotal: number;
  }> = [];

  for (const item of items) {
    const listing = listingMap.get(item.listingId);
    if (!listing) {
      throw new NotFoundError('SupplierListing', item.listingId);
    }

    if (item.quantity < listing.minOrderQty) {
      throw new BadRequestError(
        `Minimum order quantity for "${listing.name}" is ${listing.minOrderQty}`,
      );
    }

    if (listing.maxOrderQty && item.quantity > listing.maxOrderQty) {
      throw new BadRequestError(
        `Maximum order quantity for "${listing.name}" is ${listing.maxOrderQty}`,
      );
    }

    // Apply bulk pricing if applicable
    let unitPrice = listing.pricePerUnit;
    if (
      listing.bulkPrice !== null &&
      listing.bulkThreshold !== null &&
      item.quantity >= listing.bulkThreshold
    ) {
      unitPrice = listing.bulkPrice;
    }

    const lineTotal = Math.round(unitPrice * item.quantity * 100) / 100;

    orderItems.push({
      listingId: item.listingId,
      quantity: item.quantity,
      unitPrice,
      lineTotal,
    });
  }

  const totalAmount = orderItems.reduce((sum, i) => sum + i.lineTotal, 0);
  const commission = Math.round((totalAmount * MARKETPLACE_COMMISSION_PCT) / 100 * 100) / 100;

  // Create order with items in a transaction
  const order = await prisma.marketplaceOrder.create({
    data: {
      totalAmount,
      supplierId,
      businessId,
      notes: `Commission: ${commission} (${MARKETPLACE_COMMISSION_PCT}%)`,
      items: {
        create: orderItems.map((oi) => ({
          listingId: oi.listingId,
          quantity: oi.quantity,
          unitPrice: oi.unitPrice,
          lineTotal: oi.lineTotal,
        })),
      },
    },
    include: {
      items: true,
      supplier: {
        select: { id: true, businessName: true },
      },
    },
  });

  // Increment supplier's total orders
  await prisma.supplierProfile.update({
    where: { id: supplierId },
    data: { totalOrders: { increment: 1 } },
  });

  return {
    ...order,
    commission,
    commissionPct: MARKETPLACE_COMMISSION_PCT,
  };
}

export async function suggestReorder(businessId: string, itemId: string) {
  // Check if the item is low on stock
  const item = await prisma.item.findFirst({
    where: { id: itemId, businessId },
  });

  if (!item) throw new NotFoundError('Item', itemId);

  const isLowStock =
    item.minStockLevel !== null && item.centralStock <= item.minStockLevel;

  // Search marketplace listings that match by name or category
  const listings = await prisma.supplierListing.findMany({
    where: {
      isActive: true,
      supplier: { isActive: true },
      OR: [
        { name: { contains: item.name, mode: 'insensitive' } },
        { category: item.category },
      ],
    },
    include: {
      supplier: {
        select: {
          id: true,
          businessName: true,
          city: true,
          rating: true,
        },
      },
    },
    orderBy: { pricePerUnit: 'asc' },
    take: 10,
  });

  return {
    item: {
      id: item.id,
      name: item.name,
      currentStock: item.centralStock,
      minStockLevel: item.minStockLevel,
      isLowStock,
    },
    suggestions: listings,
  };
}
