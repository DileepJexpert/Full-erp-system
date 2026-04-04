export type Intent =
  | { type: 'DISPATCH_CONFIRM' }
  | { type: 'BILL_CREATE'; rawText: string }
  | { type: 'RECONCILE' }
  | { type: 'QUERY_REVENUE' }
  | { type: 'QUERY_STOCK' }
  | { type: 'QUERY_SALARY' }
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

  // Help / Menu keywords
  if (/^(help|madad|मदद|menu)/i.test(lower)) {
    return { type: 'SHOW_HELP' };
  }

  return { type: 'UNKNOWN', rawText: message };
}
