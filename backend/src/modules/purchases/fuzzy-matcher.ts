import { prisma } from '../../lib/prisma.js';

export interface MatchResult {
  itemId: string;
  itemName: string;
  confidence: number;
  matchType: 'exact' | 'alias' | 'global_alias' | 'partial';
}

/**
 * 4-level fuzzy matching for item names:
 * 1. Exact name match (case-insensitive) → confidence 1.0
 * 2. Item aliases match (item.aliases array) → confidence 0.9
 * 3. Global alias table match (ItemAliasGlobal canonical → find item) → confidence 0.8
 * 4. Partial/contains match → confidence 0.6
 */
export async function fuzzyMatchItem(
  rawText: string,
  inventoryItems: Array<{ id: string; name: string; aliases: string[]; unit: string; costPrice: number }>,
  globalAliases: Array<{ alias: string; canonical: string; category: string }>,
): Promise<MatchResult | null> {
  const normalized = rawText.trim().toLowerCase();
  if (!normalized) return null;

  // Level 1: Exact name match (case-insensitive)
  for (const item of inventoryItems) {
    if (item.name.toLowerCase() === normalized) {
      return {
        itemId: item.id,
        itemName: item.name,
        confidence: 1.0,
        matchType: 'exact',
      };
    }
  }

  // Level 2: Item aliases match
  for (const item of inventoryItems) {
    for (const alias of item.aliases) {
      if (alias.toLowerCase() === normalized) {
        return {
          itemId: item.id,
          itemName: item.name,
          confidence: 0.9,
          matchType: 'alias',
        };
      }
    }
  }

  // Level 3: Global alias table match
  for (const ga of globalAliases) {
    if (ga.alias.toLowerCase() === normalized) {
      // Found a global alias — now find the item whose name matches the canonical name
      const canonicalLower = ga.canonical.toLowerCase();
      const matchedItem = inventoryItems.find(
        (item) => item.name.toLowerCase() === canonicalLower,
      );
      if (matchedItem) {
        return {
          itemId: matchedItem.id,
          itemName: matchedItem.name,
          confidence: 0.8,
          matchType: 'global_alias',
        };
      }
    }
  }

  // Level 4: Partial/contains match
  // Check if the normalized text is contained in any item name or vice versa
  let bestPartialMatch: MatchResult | null = null;
  let bestPartialLength = 0;

  for (const item of inventoryItems) {
    const itemNameLower = item.name.toLowerCase();

    const isPartial =
      itemNameLower.includes(normalized) || normalized.includes(itemNameLower);

    if (isPartial) {
      // Prefer the match with the longest overlap
      const overlapLength = Math.min(normalized.length, itemNameLower.length);
      if (overlapLength > bestPartialLength) {
        bestPartialLength = overlapLength;
        bestPartialMatch = {
          itemId: item.id,
          itemName: item.name,
          confidence: 0.6,
          matchType: 'partial',
        };
      }
    }
  }

  if (bestPartialMatch) return bestPartialMatch;

  // Also check partial matches against item aliases
  for (const item of inventoryItems) {
    for (const alias of item.aliases) {
      const aliasLower = alias.toLowerCase();
      if (aliasLower.includes(normalized) || normalized.includes(aliasLower)) {
        return {
          itemId: item.id,
          itemName: item.name,
          confidence: 0.6,
          matchType: 'partial',
        };
      }
    }
  }

  // Also check partial matches against global aliases
  for (const ga of globalAliases) {
    if (
      ga.alias.toLowerCase().includes(normalized) ||
      normalized.includes(ga.alias.toLowerCase())
    ) {
      const canonicalLower = ga.canonical.toLowerCase();
      const matchedItem = inventoryItems.find(
        (item) => item.name.toLowerCase() === canonicalLower,
      );
      if (matchedItem) {
        return {
          itemId: matchedItem.id,
          itemName: matchedItem.name,
          confidence: 0.6,
          matchType: 'partial',
        };
      }
    }
  }

  return null;
}

/**
 * Batch version: loads items + global aliases from DB, then matches each raw text.
 */
export async function fuzzyMatchItems(
  rawTexts: string[],
  businessId: string,
): Promise<Map<string, MatchResult | null>> {
  const [inventoryItems, globalAliases] = await Promise.all([
    prisma.item.findMany({
      where: { businessId, isActive: true },
      select: { id: true, name: true, aliases: true, unit: true, costPrice: true },
    }),
    prisma.itemAliasGlobal.findMany(),
  ]);

  const results = new Map<string, MatchResult | null>();

  for (const rawText of rawTexts) {
    const match = await fuzzyMatchItem(rawText, inventoryItems, globalAliases);
    results.set(rawText, match);
  }

  return results;
}
