import { prisma } from '../../lib/prisma.js';
import { gupshup } from '../../lib/gupshup.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';

interface SessionLike {
  id: string;
  phone: string;
  businessId: string | null;
  locationId: string | null;
  stateData: unknown;
}

interface BillItemParsed {
  qty: number;
  name: string;
}

interface PaymentParsed {
  mode: 'CASH' | 'UPI' | 'MIXED';
  cashAmount: number;
  upiAmount: number;
}

/**
 * Parse bill text like "5 veg momo 3 nonveg cash" or "2 paneer roll 1 coke upi".
 * Returns parsed items and optional payment info.
 */
function parseBillText(text: string): {
  items: BillItemParsed[];
  payment: PaymentParsed | null;
} {
  const lower = text.toLowerCase().trim();
  const items: BillItemParsed[] = [];

  // Extract payment mode if present at the end
  let payment: PaymentParsed | null = null;
  let remaining = lower;

  // Check for mixed payment pattern like "80 cash 55 upi"
  const mixedMatch = remaining.match(/(\d+)\s*cash\s+(\d+)\s*upi\s*$/i);
  if (mixedMatch) {
    payment = {
      mode: 'MIXED',
      cashAmount: parseInt(mixedMatch[1], 10),
      upiAmount: parseInt(mixedMatch[2], 10),
    };
    remaining = remaining.slice(0, mixedMatch.index).trim();
  } else {
    // Check for single payment mode at end
    const cashMatch = remaining.match(/\s+cash\s*$/i);
    const upiMatch = remaining.match(/\s+upi\s*$/i);
    if (cashMatch) {
      payment = { mode: 'CASH', cashAmount: 0, upiAmount: 0 };
      remaining = remaining.slice(0, cashMatch.index).trim();
    } else if (upiMatch) {
      payment = { mode: 'UPI', cashAmount: 0, upiAmount: 0 };
      remaining = remaining.slice(0, upiMatch.index).trim();
    }
  }

  // Remove leading "bill" or "sell" or "bech" prefix
  remaining = remaining.replace(/^(bill|sell|bech|बेच|bik)\s*/i, '').trim();

  // Parse items: quantity + item name sequences
  // Pattern: number followed by words until next number or end
  const itemPattern = /(\d+)\s+([a-z\u0900-\u097F][a-z\u0900-\u097F\s]*?)(?=\s+\d|\s*$)/gi;
  let match: RegExpExecArray | null;

  while ((match = itemPattern.exec(remaining)) !== null) {
    const qty = parseInt(match[1], 10);
    const name = match[2].trim();
    if (qty > 0 && name.length > 0) {
      items.push({ qty, name });
    }
  }

  return { items, payment };
}

/**
 * Parse payment mode text: "cash", "upi", or "80 cash 55 upi".
 */
function parsePaymentText(text: string): PaymentParsed | null {
  const lower = text.toLowerCase().trim();

  const mixedMatch = lower.match(/^(\d+)\s*cash\s+(\d+)\s*upi$/i);
  if (mixedMatch) {
    return {
      mode: 'MIXED',
      cashAmount: parseInt(mixedMatch[1], 10),
      upiAmount: parseInt(mixedMatch[2], 10),
    };
  }

  if (/^cash$/i.test(lower)) return { mode: 'CASH', cashAmount: 0, upiAmount: 0 };
  if (/^upi$/i.test(lower)) return { mode: 'UPI', cashAmount: 0, upiAmount: 0 };

  return null;
}

/**
 * Resolve fuzzy item names to actual Item records.
 */
async function resolveItems(
  businessId: string,
  parsedItems: BillItemParsed[],
): Promise<Array<{ itemId: string; quantity: number; unitPrice: number; name: string }>> {
  const items = await prisma.item.findMany({
    where: { businessId },
    select: { id: true, name: true, sellingPrice: true },
  });

  const resolved: Array<{ itemId: string; quantity: number; unitPrice: number; name: string }> = [];

  for (const parsed of parsedItems) {
    // Fuzzy match: find item whose name contains parsed name or vice versa
    const found = items.find((item) => {
      const itemLower = item.name.toLowerCase();
      const parsedLower = parsed.name.toLowerCase();
      return (
        itemLower.includes(parsedLower) ||
        parsedLower.includes(itemLower) ||
        itemLower.replace(/\s+/g, '').includes(parsedLower.replace(/\s+/g, ''))
      );
    });

    if (found) {
      resolved.push({
        itemId: found.id,
        quantity: parsed.qty,
        unitPrice: found.sellingPrice as number,
        name: found.name,
      });
    }
  }

  return resolved;
}

/**
 * Create a bill via Prisma from WhatsApp-parsed data.
 */
async function createBillFromParsed(
  businessId: string,
  locationId: string,
  operatorId: string | null,
  resolvedItems: Array<{ itemId: string; quantity: number; unitPrice: number; name: string }>,
  payment: PaymentParsed,
): Promise<{ billId: string; total: number }> {
  const subtotal = resolvedItems.reduce((sum, i) => sum + i.quantity * i.unitPrice, 0);
  const total = Math.round(subtotal * 100) / 100;

  // For CASH/UPI-only modes, set the full amount
  const cashAmount = payment.mode === 'CASH' ? total : payment.mode === 'MIXED' ? payment.cashAmount : 0;
  const upiAmount = payment.mode === 'UPI' ? total : payment.mode === 'MIXED' ? payment.upiAmount : 0;

  const bill = await prisma.$transaction(async (tx) => {
    const newBill = await tx.bill.create({
      data: {
        businessId,
        locationId,
        operatorId: operatorId ?? 'whatsapp-bot',
        date: new Date(),
        subtotal,
        cgstAmount: 0,
        sgstAmount: 0,
        total,
        paymentMode: payment.mode,
        cashAmount,
        upiAmount,
        netRevenue: total,
        orderSource: 'WALK_IN',
        loyaltyPointsEarned: 0,
        loyaltyPointsRedeemed: 0,
        loyaltyDiscount: 0,
        aggregatorCommission: 0,
        items: {
          create: resolvedItems.map((i) => ({
            itemId: i.itemId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            total: Math.round(i.quantity * i.unitPrice * 100) / 100,
            cgstAmount: 0,
            sgstAmount: 0,
          })),
        },
      },
    });
    return newBill;
  });

  eventBus.emit(EVENTS.BILL_CREATED, {
    billId: bill.id,
    businessId,
    locationId,
    total,
  });

  return { billId: bill.id, total };
}

/**
 * Handle the CREATING_BILL_ITEMS / initial bill creation step.
 * Parses "5 veg momo 3 nonveg cash" format.
 * If payment mode is present, creates bill directly.
 * Otherwise transitions to CREATING_BILL_PAYMENT state.
 */
export async function handleBillCreation(
  session: SessionLike,
  message: string,
): Promise<string> {
  if (!session.businessId || !session.locationId) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'Your account is not linked to a business/location. Contact the owner.';
  }

  const { items, payment } = parseBillText(message);

  if (items.length === 0) {
    return (
      'Could not parse items. Format:\n' +
      '"bill 5 veg momo 3 chicken roll cash"\n' +
      'or "sell 2 paneer roll upi"'
    );
  }

  const resolved = await resolveItems(session.businessId, items);

  if (resolved.length === 0) {
    return 'None of those items were found in your menu. Check item names and try again.';
  }

  const unresolvedCount = items.length - resolved.length;
  let unresolvedNote = '';
  if (unresolvedCount > 0) {
    unresolvedNote = `\n(${unresolvedCount} item(s) could not be matched and were skipped)`;
  }

  // If payment mode included, create bill immediately
  if (payment) {
    const result = await createBillFromParsed(
      session.businessId,
      session.locationId,
      session.userId,
      resolved,
      payment,
    );

    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });

    const itemSummary = resolved.map((r) => `${r.quantity}x ${r.name}`).join(', ');
    return (
      `Bill created! #${result.billId.slice(-6)}\n` +
      `Items: ${itemSummary}\n` +
      `Total: Rs ${result.total}\n` +
      `Payment: ${payment.mode}${unresolvedNote}`
    );
  }

  // No payment mode - save items to state and ask for payment
  await prisma.whatsAppSession.update({
    where: { id: session.id },
    data: {
      state: 'CREATING_BILL_PAYMENT',
      stateData: { resolvedItems: resolved },
    },
  });

  const itemSummary = resolved.map((r) => `${r.quantity}x ${r.name} @ Rs ${r.unitPrice}`).join('\n');
  const total = resolved.reduce((s, i) => s + i.quantity * i.unitPrice, 0);
  return (
    `Items:\n${itemSummary}\nTotal: Rs ${total}\n\n` +
    `Payment mode? Reply:\n` +
    `"cash" / "upi" / "80 cash 55 upi" (for mixed)${unresolvedNote}`
  );
}

/**
 * Handle CREATING_BILL_PAYMENT state.
 * Parses "cash", "upi", or "80 cash 55 upi" and creates the bill.
 */
export async function handleBillPayment(
  session: SessionLike,
  message: string,
): Promise<string> {
  if (!session.businessId || !session.locationId) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'Session error. Please start again.';
  }

  const payment = parsePaymentText(message);
  if (!payment) {
    return 'Invalid payment. Reply "cash", "upi", or "80 cash 55 upi" for mixed.';
  }

  const stateData = session.stateData as { resolvedItems: Array<{ itemId: string; quantity: number; unitPrice: number; name: string }> } | null;
  if (!stateData?.resolvedItems?.length) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'No items in session. Please start a new bill.';
  }

  const result = await createBillFromParsed(
    session.businessId,
    session.locationId,
    session.userId,
    stateData.resolvedItems,
    payment,
  );

  await prisma.whatsAppSession.update({
    where: { id: session.id },
    data: { state: 'IDLE', stateData: null },
  });

  const itemSummary = stateData.resolvedItems.map((r) => `${r.quantity}x ${r.name}`).join(', ');
  return (
    `Bill created! #${result.billId.slice(-6)}\n` +
    `Items: ${itemSummary}\n` +
    `Total: Rs ${result.total}\n` +
    `Payment: ${payment.mode}`
  );
}

/**
 * Parse reconciliation text like "420/50, 260/20" (sold/returned per item).
 * Items correspond to the pending dispatch items in order.
 */
function parseReconText(text: string): Array<{ sold: number; returned: number }> {
  const entries: Array<{ sold: number; returned: number }> = [];

  // Split by comma, newline, or semicolon
  const parts = text.split(/[,;\n]+/).map((p) => p.trim()).filter(Boolean);

  for (const part of parts) {
    const match = part.match(/^(\d+)\s*[\/\\]\s*(\d+)$/);
    if (match) {
      entries.push({
        sold: parseInt(match[1], 10),
        returned: parseInt(match[2], 10),
      });
    }
  }

  return entries;
}

/**
 * Handle RECONCILING_ITEMS state.
 * Parses "420/50, 260/20" format (sold/returned per dispatch item).
 */
export async function handleReconciliation(
  session: SessionLike,
  message: string,
): Promise<string> {
  if (!session.businessId || !session.locationId) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'Your account is not linked to a business/location. Contact the owner.';
  }

  const stateData = session.stateData as { dispatchId: string } | null;
  if (!stateData?.dispatchId) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'No pending dispatch found. Please start again with "recon" or "hisab".';
  }

  const reconEntries = parseReconText(message);
  if (reconEntries.length === 0) {
    return 'Could not parse. Send sold/returned per item:\n"420/50, 260/20"\n(sold/returned, comma-separated)';
  }

  // Fetch dispatch items
  const dispatch = await prisma.dispatch.findFirst({
    where: { id: stateData.dispatchId, businessId: session.businessId },
    include: { items: { include: { item: true } } },
  });

  if (!dispatch) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'Dispatch not found. Please start again.';
  }

  if (reconEntries.length !== dispatch.items.length) {
    const itemNames = dispatch.items.map((di, i) => `${i + 1}. ${di.item.name} (sent: ${di.quantity})`).join('\n');
    return (
      `Expected ${dispatch.items.length} entries, got ${reconEntries.length}.\n` +
      `Items:\n${itemNames}\n\n` +
      `Send in format: sold/returned for each item, comma-separated.`
    );
  }

  // Build reconciliation items
  const reconItemsData = dispatch.items.map((di, i) => {
    const entry = reconEntries[i];
    const wasted = di.quantity - entry.sold - entry.returned;
    const allowedMargin = di.item.dailyMargin ?? 0;
    const chargeableLoss = Math.max(0, wasted - allowedMargin);
    const lossAmount = Math.round(chargeableLoss * (di.item.costPrice as number) * 100) / 100;

    return {
      itemId: di.itemId,
      dispatched: di.quantity,
      sold: entry.sold,
      returned: entry.returned,
      wasted: Math.max(0, wasted),
      allowedMargin,
      chargeableLoss,
      lossAmount,
    };
  });

  const totalLoss = Math.round(reconItemsData.reduce((s, r) => s + r.lossAmount, 0) * 100) / 100;
  const totalSold = reconItemsData.reduce((s, r) => s + r.sold, 0);

  // Create reconciliation record
  const recon = await prisma.$transaction(async (tx) => {
    const newRecon = await tx.reconciliation.create({
      data: {
        businessId: session.businessId!,
        dispatchId: stateData.dispatchId,
        locationId: session.locationId!,
        operatorId: session.userId ?? 'whatsapp-bot',
        date: new Date(),
        totalLoss,
        items: {
          create: reconItemsData,
        },
      },
    });

    await tx.dispatch.update({
      where: { id: stateData.dispatchId },
      data: { status: 'RECONCILED' },
    });

    return newRecon;
  });

  await prisma.whatsAppSession.update({
    where: { id: session.id },
    data: { state: 'IDLE', stateData: null },
  });

  eventBus.emit(EVENTS.RECONCILIATION_COMPLETED, {
    reconciliationId: recon.id,
    businessId: session.businessId,
    locationId: session.locationId,
    totalLoss,
  });

  const summary = dispatch.items
    .map((di, i) => {
      const e = reconEntries[i];
      return `${di.item.name}: sold ${e.sold}, returned ${e.returned}`;
    })
    .join('\n');

  return (
    `Reconciliation done!\n\n` +
    `${summary}\n\n` +
    `Total sold: ${totalSold}\n` +
    `Loss: Rs ${totalLoss}`
  );
}
