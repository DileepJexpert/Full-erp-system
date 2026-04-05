import { prisma } from '../../lib/prisma.js';

export interface DuplicateResult {
  isDuplicate: boolean;
  existingPurchaseId?: string;
  existingTotal?: number;
  existingDate?: Date;
  message?: string;
}

/**
 * Check for an existing purchase with the same supplier + same date + total within 10% range.
 */
export async function checkDuplicate(params: {
  businessId: string;
  supplierId: string | null;
  date: Date;
  totalAmount: number;
}): Promise<DuplicateResult> {
  const { businessId, supplierId, date, totalAmount } = params;

  // Cannot check duplicates without a supplier
  if (!supplierId) {
    return { isDuplicate: false };
  }

  // Build the date range: same calendar day
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  // 10% tolerance on total amount
  const lowerBound = totalAmount * 0.9;
  const upperBound = totalAmount * 1.1;

  const existing = await prisma.purchase.findFirst({
    where: {
      businessId,
      supplierId,
      date: {
        gte: startOfDay,
        lte: endOfDay,
      },
      totalAmount: {
        gte: lowerBound,
        lte: upperBound,
      },
    },
    select: {
      id: true,
      totalAmount: true,
      date: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  if (existing) {
    return {
      isDuplicate: true,
      existingPurchaseId: existing.id,
      existingTotal: Number(existing.totalAmount),
      existingDate: existing.date,
      message: `Possible duplicate: existing purchase #${existing.id} from the same supplier on the same date with total ₹${Number(existing.totalAmount).toFixed(2)} (new: ₹${totalAmount.toFixed(2)})`,
    };
  }

  return { isDuplicate: false };
}
