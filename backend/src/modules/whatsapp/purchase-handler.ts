import { prisma } from '../../lib/prisma.js';
import { parseTextBill } from '../purchases/bill-scanner.service.js';
import type { ExtractedBill } from '../purchases/bill-scanner.service.js';

/**
 * Handle purchase text parsing from WhatsApp.
 * Parses the text, formats extracted items, and asks for confirmation.
 */
export async function handlePurchaseTextParse(
  session: { id: string; phone: string; businessId: string | null; locationId: string | null },
  text: string,
): Promise<string> {
  if (!session.businessId) {
    return 'Account not linked to a business.';
  }

  try {
    const extracted = await parseTextBill(text, session.businessId);

    // Format response message
    let msg = '📦 *Purchase bill detected!*\n\n';

    if (extracted.supplier?.name) {
      msg += `Supplier: ${extracted.supplier.name}\n`;
    }
    msg += '\n';

    extracted.items.forEach((item, i) => {
      const icon = item.matchedItemId ? '✅' : '⚠️';
      msg += `${icon} ${item.rawText}: ${item.quantity} ${item.unit}`;
      msg += ` × ₹${item.unitPrice} = ₹${item.lineTotal}\n`;
    });

    msg += `\n*Total: ₹${extracted.grandTotal}*`;
    msg += '\n\nReply *OK* to save | *CANCEL* to discard';

    // Save extracted data in session state
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: {
        state: 'AWAITING_PURCHASE_CONFIRM',
        stateData: {
          extracted,
          entryMethod: 'WHATSAPP_TEXT',
          originalText: text,
        },
      },
    });

    return msg;
  } catch (error) {
    console.error('[WhatsApp] Purchase text parse error:', error);
    return 'Could not parse the purchase text. Please try again or send "help" for commands.';
  }
}

/**
 * Handle purchase confirmation or cancellation.
 */
export async function handlePurchaseConfirm(
  session: { id: string; phone: string; businessId: string | null; locationId: string | null; stateData: unknown },
  text: string,
): Promise<string> {
  const lower = text.toLowerCase().trim();

  // Cancel
  if (/^(cancel|nahi|na|no|ruk|रुक)$/i.test(lower)) {
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { state: 'IDLE', stateData: null },
    });
    return 'Purchase cancelled. Send "help" for commands.';
  }

  // Confirm
  if (/^(ok|haan|ha|yes|save|confirm|theek|ठीक)$/i.test(lower)) {
    if (!session.businessId) {
      await prisma.whatsAppSession.update({
        where: { id: session.id },
        data: { state: 'IDLE', stateData: null },
      });
      return 'Account not linked to a business.';
    }

    const stateData = session.stateData as {
      extracted: ExtractedBill;
      entryMethod: string;
    } | null;

    if (!stateData?.extracted) {
      await prisma.whatsAppSession.update({
        where: { id: session.id },
        data: { state: 'IDLE', stateData: null },
      });
      return 'No purchase data found. Please try again.';
    }

    const { extracted, entryMethod } = stateData;

    try {
      // Find or auto-select supplier
      let supplierId: string | null = extracted.supplier?.matchedId ?? null;
      if (!supplierId) {
        // Try to find a generic supplier or create one
        const defaultSupplier = await prisma.supplier.findFirst({
          where: { businessId: session.businessId, name: 'WhatsApp Supplier' },
        });
        if (defaultSupplier) {
          supplierId = defaultSupplier.id;
        } else {
          const created = await prisma.supplier.create({
            data: {
              businessId: session.businessId,
              name: extracted.supplier?.name || 'WhatsApp Supplier',
              phone: extracted.supplier?.phone || session.phone,
            },
          });
          supplierId = created.id;
        }
      }

      // Filter to only matched items
      const matchedItems = extracted.items.filter((i) => i.matchedItemId);
      if (matchedItems.length === 0) {
        await prisma.whatsAppSession.update({
          where: { id: session.id },
          data: { state: 'IDLE', stateData: null },
        });
        return 'No items could be matched to your inventory. Add items first, then try again.';
      }

      // Find user for createdById
      const user = await prisma.user.findFirst({
        where: { phone: session.phone, businessId: session.businessId },
      });

      const totalAmount = matchedItems.reduce((s, i) => s + i.lineTotal, 0);

      // Create purchase
      const purchase = await prisma.$transaction(async (tx) => {
        const p = await tx.purchase.create({
          data: {
            businessId: session.businessId!,
            supplierId: supplierId!,
            createdById: user?.id ?? supplierId!,
            date: new Date(),
            totalAmount,
            entryMethod,
            aiExtractedRaw: extracted as any,
            aiConfidence: extracted.confidence,
            approvalStatus: 'AUTO_APPROVED',
            items: {
              create: matchedItems.map((i) => ({
                itemId: i.matchedItemId!,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                lineTotal: i.lineTotal,
              })),
            },
          },
        });

        // Update stock
        for (const item of matchedItems) {
          await tx.item.update({
            where: { id: item.matchedItemId! },
            data: {
              centralStock: { increment: item.quantity },
              lastPurchasePrice: item.unitPrice,
            },
          });
        }

        return p;
      });

      await prisma.whatsAppSession.update({
        where: { id: session.id },
        data: { state: 'IDLE', stateData: null },
      });

      return (
        `✅ *Purchase saved!*\n` +
        `${matchedItems.length} items | ₹${totalAmount}\n` +
        `Stock updated. Purchase #${purchase.id.slice(-6)}`
      );
    } catch (error) {
      console.error('[WhatsApp] Purchase save error:', error);
      await prisma.whatsAppSession.update({
        where: { id: session.id },
        data: { state: 'IDLE', stateData: null },
      });
      return 'Error saving purchase. Please try again.';
    }
  }

  return 'Reply *OK* to save the purchase or *CANCEL* to discard.';
}
