export type Intent =
  | { type: 'DISPATCH_CONFIRM' }
  | { type: 'BILL_CREATE'; rawText: string }
  | { type: 'RECONCILE' }
  | { type: 'QUERY_REVENUE' }
  | { type: 'QUERY_STOCK' }
  | { type: 'QUERY_SALARY' }
  | { type: 'PURCHASE_TEXT'; rawText: string }
  | { type: 'SHOW_HELP' }
  | { type: 'STATE_CONTINUE' }
  | { type: 'UNKNOWN'; rawText: string };

/**
 * Classify inbound WhatsApp message intent using keyword matching.
 * Supports both Hindi and English keywords.
 */
export function classifyIntent(message: string, sessionState: string): Intent {
  const lower = message.toLowerCase().trim();

  // If the session is in an active state, route back to state handler
  if (sessionState !== 'IDLE') {
    return { type: 'STATE_CONTINUE' };
  }

  // Confirmation keywords (Hindi + English)
  if (/^(confirm|haan|ha|ok|theek|ठीक)$/i.test(lower)) {
    return { type: 'DISPATCH_CONFIRM' };
  }

  // Bill / Sell keywords
  if (/^(bill|sell|bech|बेच|bik)/i.test(lower)) {
    return { type: 'BILL_CREATE', rawText: message };
  }

  // Reconciliation keywords
  if (/^(recon|hisab|हिसाब|reconcil)/i.test(lower)) {
    return { type: 'RECONCILE' };
  }

  // Revenue query keywords
  if (/(revenue|kamai|कमाई|aaj|today|kitna)/i.test(lower)) {
    return { type: 'QUERY_REVENUE' };
  }

  // Stock / Inventory keywords
  if (/(stock|maal|माल|inventory)/i.test(lower)) {
    return { type: 'QUERY_STOCK' };
  }

  // Salary keywords
  if (/(salary|tankhwah|तनख्वाह|vetan)/i.test(lower)) {
    return { type: 'QUERY_SALARY' };
  }

  // Purchase-like text detection (numbers + items + prices)
  if (looksLikePurchase(lower)) {
    return { type: 'PURCHASE_TEXT', rawText: message };
  }

  // Help / Menu keywords
  if (/^(help|madad|मदद|menu)/i.test(lower)) {
    return { type: 'SHOW_HELP' };
  }

  return { type: 'UNKNOWN', rawText: message };
}

/**
 * Detect if a text message looks like a purchase/delivery bill.
 * Patterns: numbers + item-like words + price indicators.
 * E.g. "500 plate 200 cup 50 sauce total 3500" or "20kg pyaaz 40/kg"
 */
export function looksLikePurchase(text: string): boolean {
  const lower = text.toLowerCase();
  const pricePattern = /(\d+)\s*(rs|rupay|rupee|rupaiye|@|\/-)/i;
  const qtyPattern = /(\d+)\s*(kg|kilo|pcs|packet|strip|bottle|litre|dozen|box|pack)/i;
  const totalPattern = /(total|kul|jama|grand)/i;
  const digitCount = (lower.match(/\d/g) || []).length;

  // Must have at least 3 digits and either price or quantity patterns
  if (digitCount < 3) return false;
  if (pricePattern.test(lower) || qtyPattern.test(lower)) return true;
  if (totalPattern.test(lower) && digitCount >= 4) return true;
  return false;
}
