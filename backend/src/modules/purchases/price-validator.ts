import { prisma } from '../../lib/prisma.js';

export interface PriceAlert {
  itemId: string;
  itemName: string;
  lastPrice: number;
  newPrice: number;
  percentChange: number;
  message: string;
}

const PRICE_CHANGE_THRESHOLD = 10; // percent

/**
 * Compare each item's new price against its lastPurchasePrice.
 * Flag items where the difference exceeds 10%.
 * Skip items without a lastPurchasePrice (first-time purchases).
 */
export async function validatePrices(
  items: Array<{ matchedItemId: string | null; unitPrice: number }>,
  businessId: string,
): Promise<PriceAlert[]> {
  const alerts: PriceAlert[] = [];

  // Collect valid item IDs
  const itemIds = items
    .map((i) => i.matchedItemId)
    .filter((id): id is string => id !== null);

  if (itemIds.length === 0) return alerts;

  // Fetch items with their last purchase price in a single query
  const dbItems = await prisma.item.findMany({
    where: { id: { in: itemIds }, businessId },
    select: { id: true, name: true, lastPurchasePrice: true },
  });

  const itemMap = new Map(dbItems.map((i) => [i.id, i]));

  for (const entry of items) {
    if (!entry.matchedItemId) continue;

    const dbItem = itemMap.get(entry.matchedItemId);
    if (!dbItem) continue;

    // Skip first-time purchases (no last purchase price)
    if (dbItem.lastPurchasePrice === null || dbItem.lastPurchasePrice === 0) {
      continue;
    }

    const lastPrice = Number(dbItem.lastPurchasePrice);
    const newPrice = entry.unitPrice;
    const percentChange =
      Math.round(((newPrice - lastPrice) / lastPrice) * 10000) / 100;

    if (Math.abs(percentChange) > PRICE_CHANGE_THRESHOLD) {
      const direction = percentChange > 0 ? 'increased' : 'decreased';
      alerts.push({
        itemId: dbItem.id,
        itemName: dbItem.name,
        lastPrice,
        newPrice,
        percentChange,
        message: `${dbItem.name} price ${direction} by ${Math.abs(percentChange).toFixed(1)}% (₹${lastPrice} → ₹${newPrice})`,
      });
    }
  }

  return alerts;
}
