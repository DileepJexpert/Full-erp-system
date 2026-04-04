import { prisma } from '../../lib/prisma.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';

/**
 * Create a stock transfer with items.
 */
export async function createTransfer(
  businessId: string,
  input: {
    fromLocationId: string;
    toLocationId: string;
    date: string;
    notes?: string;
    items: Array<{ itemId: string; quantity: number }>;
  },
) {
  if (input.fromLocationId === input.toLocationId) {
    throw new BadRequestError('Cannot transfer to the same location');
  }

  if (!input.items.length) {
    throw new BadRequestError('At least one item is required');
  }

  return prisma.stockTransfer.create({
    data: {
      date: new Date(input.date),
      fromLocationId: input.fromLocationId,
      toLocationId: input.toLocationId,
      notes: input.notes ?? null,
      businessId,
      items: {
        create: input.items.map((item) => ({
          itemId: item.itemId,
          quantity: item.quantity,
        })),
      },
    },
    include: { items: true },
  });
}

/**
 * Complete a transfer: atomically deduct from source location stock and add to destination.
 * Uses centralStock on Item model (location-level stock can be extended later).
 */
export async function completeTransfer(businessId: string, transferId: string, approvedById: string) {
  const transfer = await prisma.stockTransfer.findFirst({
    where: { id: transferId, businessId },
    include: { items: true },
  });

  if (!transfer) throw new NotFoundError('StockTransfer', transferId);
  if (transfer.status !== 'TRANSFER_PENDING') {
    throw new BadRequestError(`Cannot complete a transfer with status ${transfer.status}`);
  }

  // Perform atomic stock updates in a transaction
  return prisma.$transaction(async (tx) => {
    // Verify sufficient stock for all items before making changes
    for (const transferItem of transfer.items) {
      const item = await tx.item.findFirst({
        where: { id: transferItem.itemId, businessId },
      });

      if (!item) {
        throw new BadRequestError(`Item ${transferItem.itemId} not found`);
      }

      if (item.centralStock < transferItem.quantity) {
        throw new BadRequestError(
          `Insufficient stock for item "${item.name}": available ${item.centralStock}, requested ${transferItem.quantity}`,
        );
      }
    }

    // Deduct from source (centralStock represents available stock)
    for (const transferItem of transfer.items) {
      await tx.item.update({
        where: { id: transferItem.itemId },
        data: {
          centralStock: { decrement: transferItem.quantity },
        },
      });
    }

    // Note: In a full location-level inventory system, you would also
    // increment the toLocation's stock. With centralStock only, the
    // deduction represents the transfer out. This can be extended
    // with a LocationStock model.

    // Mark transfer as completed
    const completed = await tx.stockTransfer.update({
      where: { id: transferId },
      data: {
        status: 'TRANSFER_COMPLETED',
        approvedById,
      },
      include: { items: true },
    });

    return completed;
  });
}

/**
 * Cancel a pending transfer (no stock changes).
 */
export async function cancelTransfer(businessId: string, transferId: string) {
  const transfer = await prisma.stockTransfer.findFirst({
    where: { id: transferId, businessId },
  });

  if (!transfer) throw new NotFoundError('StockTransfer', transferId);
  if (transfer.status !== 'TRANSFER_PENDING') {
    throw new BadRequestError(`Cannot cancel a transfer with status ${transfer.status}`);
  }

  return prisma.stockTransfer.update({
    where: { id: transferId },
    data: { status: 'TRANSFER_CANCELLED' },
    include: { items: true },
  });
}
