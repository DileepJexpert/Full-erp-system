// Smart Purchase Entry System — Unit Tests
import { describe, it, expect } from 'vitest';

// ═══ Fuzzy Matching Tests ═══
describe('Fuzzy Item Matching', () => {
  const inventoryItems = [
    { id: '1', name: 'Onion', aliases: ['pyaaz', 'kanda'], unit: 'kg', costPrice: 30 },
    { id: '2', name: 'Potato', aliases: ['aloo', 'batata'], unit: 'kg', costPrice: 20 },
    { id: '3', name: 'Tomato', aliases: ['tamatar'], unit: 'kg', costPrice: 40 },
    { id: '4', name: 'Wheat Flour', aliases: ['atta', 'gehun ka atta'], unit: 'kg', costPrice: 35 },
    { id: '5', name: 'Paneer', aliases: ['paneer'], unit: 'kg', costPrice: 320 },
    { id: '6', name: 'Paracetamol 500mg', aliases: ['crocin', 'dolo'], unit: 'strip', costPrice: 15 },
    { id: '7', name: 'Rice', aliases: ['chawal'], unit: 'kg', costPrice: 50 },
    { id: '8', name: 'Mustard Oil', aliases: ['sarson ka tel'], unit: 'litre', costPrice: 180 },
  ];

  const globalAliases = [
    { alias: 'pyaaz', canonical: 'Onion', category: 'vegetable' },
    { alias: 'kanda', canonical: 'Onion', category: 'vegetable' },
    { alias: 'gobhi', canonical: 'Cabbage', category: 'vegetable' },
    { alias: 'aloo', canonical: 'Potato', category: 'vegetable' },
    { alias: 'atta', canonical: 'Wheat Flour', category: 'staple' },
    { alias: 'doodh', canonical: 'Milk', category: 'dairy' },
    { alias: 'chawal', canonical: 'Rice', category: 'staple' },
  ];

  function fuzzyMatchItem(rawText: string) {
    const normalized = rawText.toLowerCase().trim();

    // Level 1: Exact name match
    const exact = inventoryItems.find((i) => i.name.toLowerCase() === normalized);
    if (exact) return { itemId: exact.id, itemName: exact.name, confidence: 1.0, matchType: 'exact' };

    // Level 2: Item aliases
    const aliasItem = inventoryItems.find((i) =>
      i.aliases.some((a) => a.toLowerCase() === normalized),
    );
    if (aliasItem) return { itemId: aliasItem.id, itemName: aliasItem.name, confidence: 0.9, matchType: 'alias' };

    // Level 3: Global alias table
    const globalMatch = globalAliases.find((a) => a.alias.toLowerCase() === normalized);
    if (globalMatch) {
      const item = inventoryItems.find((i) => i.name.toLowerCase() === globalMatch.canonical.toLowerCase());
      if (item) return { itemId: item.id, itemName: item.name, confidence: 0.8, matchType: 'global_alias' };
    }

    // Level 4: Partial match
    const partial = inventoryItems.find(
      (i) => i.name.toLowerCase().includes(normalized) || normalized.includes(i.name.toLowerCase()),
    );
    if (partial) return { itemId: partial.id, itemName: partial.name, confidence: 0.6, matchType: 'partial' };

    return null;
  }

  it('should match exact item name (case-insensitive)', () => {
    const result = fuzzyMatchItem('Onion');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Onion');
    expect(result!.confidence).toBe(1.0);
    expect(result!.matchType).toBe('exact');
  });

  it('should match exact name case-insensitively', () => {
    const result = fuzzyMatchItem('POTATO');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Potato');
  });

  it('should match Hindi alias (pyaaz → Onion)', () => {
    const result = fuzzyMatchItem('pyaaz');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Onion');
    expect(result!.confidence).toBe(0.9);
    expect(result!.matchType).toBe('alias');
  });

  it('should match regional alias (kanda → Onion)', () => {
    const result = fuzzyMatchItem('kanda');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Onion');
  });

  it('should match Hindi alias (atta → Wheat Flour)', () => {
    const result = fuzzyMatchItem('atta');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Wheat Flour');
  });

  it('should match medicine alias (crocin → Paracetamol 500mg)', () => {
    const result = fuzzyMatchItem('crocin');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Paracetamol 500mg');
  });

  it('should match via global alias table (chawal → Rice)', () => {
    // chawal is both in item aliases AND global — item alias takes precedence
    const result = fuzzyMatchItem('chawal');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Rice');
    expect(result!.matchType).toBe('alias'); // Found in item aliases first
  });

  it('should match partial name (Mustard → Mustard Oil)', () => {
    const result = fuzzyMatchItem('mustard');
    expect(result).not.toBeNull();
    expect(result!.itemName).toBe('Mustard Oil');
    expect(result!.confidence).toBe(0.6);
    expect(result!.matchType).toBe('partial');
  });

  it('should return null for completely unknown items', () => {
    const result = fuzzyMatchItem('xyzabc123');
    expect(result).toBeNull();
  });
});

// ═══ Price Validation Tests ═══
describe('Price Validation', () => {
  function validatePrice(lastPrice: number | null, newPrice: number) {
    if (!lastPrice || lastPrice === 0) return null; // Skip first purchase
    const percentChange = ((newPrice - lastPrice) / lastPrice) * 100;
    if (percentChange > 10) {
      return {
        lastPrice,
        newPrice,
        percentChange: Math.round(percentChange),
        message: `Price up ${Math.round(percentChange)}% (${lastPrice} → ${newPrice})`,
      };
    }
    return null;
  }

  it('should flag price increase > 10%', () => {
    const alert = validatePrice(100, 115);
    expect(alert).not.toBeNull();
    expect(alert!.percentChange).toBe(15);
  });

  it('should NOT flag price increase <= 10%', () => {
    const alert = validatePrice(100, 108);
    expect(alert).toBeNull();
  });

  it('should NOT flag price decrease', () => {
    const alert = validatePrice(100, 80);
    expect(alert).toBeNull();
  });

  it('should skip validation for first purchase (no last price)', () => {
    const alert = validatePrice(null, 100);
    expect(alert).toBeNull();
  });

  it('should flag 50% price increase', () => {
    const alert = validatePrice(40, 60);
    expect(alert).not.toBeNull();
    expect(alert!.percentChange).toBe(50);
  });
});

// ═══ Duplicate Detection Tests ═══
describe('Duplicate Detection', () => {
  function isDuplicate(
    existingPurchases: Array<{ supplierId: string; date: string; totalAmount: number }>,
    newPurchase: { supplierId: string; date: string; totalAmount: number },
  ): boolean {
    return existingPurchases.some(
      (p) =>
        p.supplierId === newPurchase.supplierId &&
        p.date === newPurchase.date &&
        p.totalAmount >= newPurchase.totalAmount * 0.9 &&
        p.totalAmount <= newPurchase.totalAmount * 1.1,
    );
  }

  const existing = [
    { supplierId: 's1', date: '2026-04-05', totalAmount: 5000 },
    { supplierId: 's2', date: '2026-04-05', totalAmount: 3200 },
  ];

  it('should detect exact duplicate', () => {
    expect(isDuplicate(existing, { supplierId: 's1', date: '2026-04-05', totalAmount: 5000 })).toBe(true);
  });

  it('should detect near-duplicate (within 10%)', () => {
    expect(isDuplicate(existing, { supplierId: 's1', date: '2026-04-05', totalAmount: 5200 })).toBe(true);
  });

  it('should NOT flag different supplier', () => {
    expect(isDuplicate(existing, { supplierId: 's3', date: '2026-04-05', totalAmount: 5000 })).toBe(false);
  });

  it('should NOT flag different date', () => {
    expect(isDuplicate(existing, { supplierId: 's1', date: '2026-04-06', totalAmount: 5000 })).toBe(false);
  });

  it('should NOT flag significantly different amount (>10%)', () => {
    expect(isDuplicate(existing, { supplierId: 's1', date: '2026-04-05', totalAmount: 8000 })).toBe(false);
  });
});

// ═══ Purchase Text Detection Tests ═══
describe('Purchase Text Detection (looksLikePurchase)', () => {
  function looksLikePurchase(text: string): boolean {
    const lower = text.toLowerCase();
    const pricePattern = /(\d+)\s*(rs|rupay|rupee|rupaiye|@|\/-)/i;
    const qtyPattern = /(\d+)\s*(kg|kilo|pcs|packet|strip|bottle|litre|dozen|box|pack)/i;
    const totalPattern = /(total|kul|jama|grand)/i;
    const digitCount = (lower.match(/\d/g) || []).length;

    if (digitCount < 3) return false;
    if (pricePattern.test(lower) || qtyPattern.test(lower)) return true;
    if (totalPattern.test(lower) && digitCount >= 4) return true;
    return false;
  }

  it('should detect "500 plate 200 cup total 3500"', () => {
    expect(looksLikePurchase('500 plate 200 cup total 3500')).toBe(true);
  });

  it('should detect "20kg pyaaz 40 rs/kg"', () => {
    expect(looksLikePurchase('20kg pyaaz 40 rs/kg')).toBe(true);
  });

  it('should detect "atta 10kg @35 maida 5kg @32 total 670"', () => {
    expect(looksLikePurchase('atta 10kg @35 maida 5kg @32 total 670')).toBe(true);
  });

  it('should detect "5 strip crocin 12 rs 3 bottle syrup 45 rs"', () => {
    expect(looksLikePurchase('5 strip crocin 12 rs 3 bottle syrup 45 rs')).toBe(true);
  });

  it('should NOT detect "hello how are you"', () => {
    expect(looksLikePurchase('hello how are you')).toBe(false);
  });

  it('should NOT detect "bill 5 veg momo" (bill intent, not purchase)', () => {
    // This has only 1 digit, not enough for purchase detection
    expect(looksLikePurchase('bill 5 veg momo')).toBe(false);
  });

  it('should NOT detect "hisab batao" (reconciliation, no numbers)', () => {
    expect(looksLikePurchase('hisab batao')).toBe(false);
  });

  it('should detect Hindi quantity "10 kilo pyaaz 40 rupay"', () => {
    expect(looksLikePurchase('10 kilo pyaaz 40 rupay')).toBe(true);
  });
});

// ═══ Approval Flow Tests ═══
describe('Approval Flow', () => {
  function getApprovalStatus(
    totalAmount: number,
    threshold: number,
    userRole: string,
  ): string {
    if (threshold === 0) return 'AUTO_APPROVED';
    if (userRole === 'OWNER') return 'AUTO_APPROVED';
    if (totalAmount <= threshold) return 'AUTO_APPROVED';
    return 'PENDING_APPROVAL';
  }

  it('should auto-approve when threshold is 0 (disabled)', () => {
    expect(getApprovalStatus(50000, 0, 'STAFF')).toBe('AUTO_APPROVED');
  });

  it('should auto-approve when owner enters any amount', () => {
    expect(getApprovalStatus(100000, 5000, 'OWNER')).toBe('AUTO_APPROVED');
  });

  it('should auto-approve when amount <= threshold', () => {
    expect(getApprovalStatus(3000, 5000, 'STAFF')).toBe('AUTO_APPROVED');
  });

  it('should require approval when staff enters amount > threshold', () => {
    expect(getApprovalStatus(8000, 5000, 'STAFF')).toBe('PENDING_APPROVAL');
  });

  it('should require approval when manager enters amount > threshold', () => {
    expect(getApprovalStatus(10000, 5000, 'MANAGER')).toBe('PENDING_APPROVAL');
  });
});

// ═══ Average Price Calculation Tests ═══
describe('Average Price Calculation', () => {
  function calculateAvgPrice(currentAvg: number | null, newPrice: number): number {
    if (currentAvg === null || currentAvg === 0) return newPrice;
    return currentAvg * 0.8 + newPrice * 0.2;
  }

  it('should use new price as average for first purchase', () => {
    expect(calculateAvgPrice(null, 100)).toBe(100);
  });

  it('should calculate weighted average (80% old + 20% new)', () => {
    expect(calculateAvgPrice(100, 150)).toBe(110);
  });

  it('should handle price decrease', () => {
    expect(calculateAvgPrice(100, 50)).toBe(90);
  });

  it('should converge gradually with same price', () => {
    let avg = 100;
    avg = calculateAvgPrice(avg, 120); // 104
    avg = calculateAvgPrice(avg, 120); // 107.2
    avg = calculateAvgPrice(avg, 120); // 109.76
    expect(avg).toBeCloseTo(109.76);
  });
});

// ═══ Template Suggestion Tests ═══
describe('Template Suggestion', () => {
  function shouldSuggestTemplate(purchaseCount: number, templateExists: boolean): boolean {
    return purchaseCount >= 3 && !templateExists;
  }

  it('should suggest after 3rd purchase if no template', () => {
    expect(shouldSuggestTemplate(3, false)).toBe(true);
  });

  it('should NOT suggest if template already exists', () => {
    expect(shouldSuggestTemplate(5, true)).toBe(false);
  });

  it('should NOT suggest before 3 purchases', () => {
    expect(shouldSuggestTemplate(2, false)).toBe(false);
  });

  it('should suggest on 10th purchase without template', () => {
    expect(shouldSuggestTemplate(10, false)).toBe(true);
  });
});

// ═══ Bill Photo Detection Tests (WhatsApp) ═══
describe('WhatsApp Purchase Confirmation', () => {
  function isConfirmation(text: string): boolean {
    return /^(ok|haan|ha|yes|save|confirm|theek|ठीक)$/i.test(text.trim());
  }

  function isCancellation(text: string): boolean {
    return /^(cancel|nahi|na|no|ruk|रुक)$/i.test(text.trim());
  }

  it('should recognize "ok" as confirmation', () => {
    expect(isConfirmation('ok')).toBe(true);
  });

  it('should recognize "haan" as confirmation', () => {
    expect(isConfirmation('haan')).toBe(true);
  });

  it('should recognize "cancel" as cancellation', () => {
    expect(isCancellation('cancel')).toBe(true);
  });

  it('should recognize "nahi" as cancellation', () => {
    expect(isCancellation('nahi')).toBe(true);
  });

  it('should NOT recognize random text as confirmation', () => {
    expect(isConfirmation('hello world')).toBe(false);
  });
});
