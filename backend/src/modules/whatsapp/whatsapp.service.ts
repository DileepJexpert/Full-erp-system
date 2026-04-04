import { prisma } from '../../lib/prisma.js';
import { gupshup } from '../../lib/gupshup.js';
import { classifyIntent, type Intent } from './intent-classifier.js';
import {
  handleBillCreation,
  handleBillPayment,
  handleReconciliation,
} from './state-machine.js';

/**
 * Find or create a WhatsApp session for a phone number.
 */
async function getOrCreateSession(phone: string) {
  let session = await prisma.whatsAppSession.findUnique({
    where: { phone },
  });

  if (!session) {
    // Try to find a user linked to this phone
    const user = await prisma.user.findFirst({
      where: { phone },
      select: { id: true, businessId: true, locationId: true },
    });

    session = await prisma.whatsAppSession.create({
      data: {
        phone,
        state: 'IDLE',
        userId: user?.id ?? null,
        businessId: user?.businessId ?? null,
        locationId: user?.locationId ?? null,
      },
    });
  } else {
    // Update last activity
    await prisma.whatsAppSession.update({
      where: { id: session.id },
      data: { lastActivity: new Date() },
    });
  }

  return session;
}

/**
 * Log an inbound or outbound message.
 */
async function logMessage(
  sessionId: string,
  direction: 'INBOUND' | 'OUTBOUND',
  content: string,
  businessId: string | null,
  waMessageId?: string,
): Promise<void> {
  await prisma.whatsAppMessage.create({
    data: {
      sessionId,
      direction,
      type: 'TEXT',
      content,
      waMessageId: waMessageId ?? null,
      businessId,
    },
  });
}

/**
 * Handle a revenue query.
 */
async function handleRevenueQuery(businessId: string): Promise<string> {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const bills = await prisma.bill.findMany({
    where: {
      businessId,
      date: { gte: today },
    },
    select: {
      total: true,
      cashAmount: true,
      upiAmount: true,
    },
  });

  if (bills.length === 0) {
    return 'Aaj ka koi bill nahi hai abhi. (No bills today yet)';
  }

  const totalRevenue = bills.reduce((s, b) => s + (b.total as number), 0);
  const totalCash = bills.reduce((s, b) => s + (b.cashAmount as number || 0), 0);
  const totalUpi = bills.reduce((s, b) => s + (b.upiAmount as number || 0), 0);

  return (
    `*Aaj ka hisab:*\n` +
    `Revenue: Rs ${Math.round(totalRevenue).toLocaleString('en-IN')}\n` +
    `Bills: ${bills.length}\n` +
    `Cash: Rs ${Math.round(totalCash).toLocaleString('en-IN')}\n` +
    `UPI: Rs ${Math.round(totalUpi).toLocaleString('en-IN')}`
  );
}

/**
 * Handle a stock query.
 */
async function handleStockQuery(businessId: string, locationId: string | null): Promise<string> {
  const where: Record<string, unknown> = { businessId };
  if (locationId) {
    // Items don't have locationId; we query dispatch items or inventory by location
    // For simplicity, return all items with stock info
  }

  const items = await prisma.item.findMany({
    where: { businessId },
    select: { name: true, currentStock: true, minStock: true },
    orderBy: { currentStock: 'asc' },
    take: 10,
  });

  if (items.length === 0) {
    return 'No items found in inventory.';
  }

  const lines = items.map((item) => {
    const warning = (item.currentStock ?? 0) <= (item.minStock ?? 0) ? ' LOW' : '';
    return `${item.name}: ${item.currentStock ?? 0}${warning}`;
  });

  return `*Stock Status (lowest first):*\n${lines.join('\n')}`;
}

/**
 * Handle a salary query.
 */
async function handleSalaryQuery(businessId: string, phone: string): Promise<string> {
  const user = await prisma.user.findFirst({
    where: { phone, businessId },
    select: { id: true, name: true },
  });

  if (!user) {
    return 'Your phone is not linked to any staff record.';
  }

  const latestSalary = await prisma.salaryRecord.findFirst({
    where: { businessId, userId: user.id },
    orderBy: { createdAt: 'desc' },
  });

  if (!latestSalary) {
    return 'No salary records found for you.';
  }

  return (
    `*Salary Info - ${user.name}*\n` +
    `Base: Rs ${(latestSalary.baseSalary as number).toLocaleString('en-IN')}\n` +
    `Deductions: Rs ${(latestSalary.totalDeductions as number).toLocaleString('en-IN')}\n` +
    `Net: Rs ${(latestSalary.netSalary as number).toLocaleString('en-IN')}`
  );
}

/**
 * Get help / menu text.
 */
function getHelpText(): string {
  return (
    `*Available Commands:*\n\n` +
    `"bill 5 veg momo 3 chicken cash" - Create bill\n` +
    `"recon" / "hisab" - Start reconciliation\n` +
    `"confirm" / "haan" - Confirm dispatch\n` +
    `"revenue" / "kamai" / "aaj" - Today's revenue\n` +
    `"stock" / "maal" - Stock levels\n` +
    `"salary" / "tankhwah" - Salary info\n` +
    `"help" / "madad" - This menu`
  );
}

/**
 * Route intent to the appropriate handler and return response text.
 */
async function handleIntent(
  intent: Intent,
  session: Awaited<ReturnType<typeof getOrCreateSession>>,
  message: string,
): Promise<string> {
  switch (intent.type) {
    case 'DISPATCH_CONFIRM': {
      if (!session.businessId) return 'Account not linked to a business.';

      // Find latest unconfirmed dispatch for this location
      const dispatch = await prisma.dispatch.findFirst({
        where: {
          businessId: session.businessId,
          locationId: session.locationId ?? undefined,
          status: 'PENDING',
        },
        orderBy: { createdAt: 'desc' },
        include: { items: { include: { item: true } } },
      });

      if (!dispatch) {
        return 'Koi pending dispatch nahi mila. (No pending dispatch found)';
      }

      await prisma.dispatch.update({
        where: { id: dispatch.id },
        data: { status: 'CONFIRMED' },
      });

      const itemList = dispatch.items.map((di) => `${di.item.name}: ${di.quantity}`).join(', ');
      return `Dispatch confirmed! ${itemList}`;
    }

    case 'BILL_CREATE':
      return handleBillCreation(session, message);

    case 'RECONCILE': {
      if (!session.businessId || !session.locationId) {
        return 'Account not linked to a business/location.';
      }

      // Find latest confirmed (un-reconciled) dispatch
      const dispatch = await prisma.dispatch.findFirst({
        where: {
          businessId: session.businessId,
          locationId: session.locationId,
          status: 'CONFIRMED',
        },
        orderBy: { createdAt: 'desc' },
        include: { items: { include: { item: true } } },
      });

      if (!dispatch) {
        return 'Koi confirmed dispatch nahi mila. (No dispatch to reconcile)';
      }

      const itemNames = dispatch.items
        .map((di, i) => `${i + 1}. ${di.item.name} (sent: ${di.quantity})`)
        .join('\n');

      await prisma.whatsAppSession.update({
        where: { id: session.id },
        data: {
          state: 'RECONCILING_ITEMS',
          stateData: { dispatchId: dispatch.id },
        },
      });

      return (
        `Dispatch #${dispatch.id.slice(-6)} items:\n${itemNames}\n\n` +
        `Send sold/returned for each item:\n` +
        `"420/50, 260/20" (sold/returned, comma-separated)`
      );
    }

    case 'QUERY_REVENUE':
      if (!session.businessId) return 'Account not linked to a business.';
      return handleRevenueQuery(session.businessId);

    case 'QUERY_STOCK':
      if (!session.businessId) return 'Account not linked to a business.';
      return handleStockQuery(session.businessId, session.locationId);

    case 'QUERY_SALARY':
      if (!session.businessId) return 'Account not linked to a business.';
      return handleSalaryQuery(session.businessId, session.phone);

    case 'SHOW_HELP':
      return getHelpText();

    case 'STATE_CONTINUE':
      // This shouldn't be reached via handleIntent; handled separately
      return 'Something went wrong. Send "help" to see commands.';

    case 'UNKNOWN':
      return (
        `Samajh nahi aaya. (Didn't understand)\n\n` +
        `Send "help" or "madad" to see commands.`
      );
  }
}

/**
 * Main inbound message processor.
 * Called asynchronously after webhook returns 200.
 */
export async function processInboundMessage(
  phone: string,
  text: string,
  waMessageId?: string,
): Promise<void> {
  try {
    const session = await getOrCreateSession(phone);

    // Log the inbound message
    await logMessage(session.id, 'INBOUND', text, session.businessId, waMessageId);

    let response: string;
    const currentState = session.state as string;

    if (currentState !== 'IDLE') {
      // Route to active state handler
      switch (currentState) {
        case 'CREATING_BILL_ITEMS':
          response = await handleBillCreation(session, text);
          break;
        case 'CREATING_BILL_PAYMENT':
          response = await handleBillPayment(session, text);
          break;
        case 'RECONCILING_ITEMS':
          response = await handleReconciliation(session, text);
          break;
        case 'AWAITING_DISPATCH_CONFIRM': {
          if (/^(confirm|haan|ha|ok|theek|ठीक|yes)$/i.test(text.trim())) {
            const stateData = session.stateData as { dispatchId: string } | null;
            if (stateData?.dispatchId) {
              await prisma.dispatch.update({
                where: { id: stateData.dispatchId },
                data: { status: 'CONFIRMED' },
              });
              await prisma.whatsAppSession.update({
                where: { id: session.id },
                data: { state: 'IDLE', stateData: null },
              });
              response = 'Dispatch confirmed!';
            } else {
              response = 'No dispatch to confirm. State reset.';
              await prisma.whatsAppSession.update({
                where: { id: session.id },
                data: { state: 'IDLE', stateData: null },
              });
            }
          } else {
            response = 'Reply "confirm" / "haan" to confirm, or "help" for menu.';
          }
          break;
        }
        default:
          response = 'Unknown state. Resetting. Send "help" for commands.';
          await prisma.whatsAppSession.update({
            where: { id: session.id },
            data: { state: 'IDLE', stateData: null },
          });
      }
    } else {
      // Classify intent and handle
      const intent = classifyIntent(text, currentState);
      response = await handleIntent(intent, session, text);
    }

    // Send response via WhatsApp
    await gupshup.sendText(phone, response);

    // Log the outbound message
    await logMessage(session.id, 'OUTBOUND', response, session.businessId);
  } catch (error) {
    console.error(`[WhatsApp] Error processing message from ${phone}:`, error);

    try {
      await gupshup.sendText(phone, 'Sorry, kuch gadbad ho gayi. Please try again.');
    } catch {
      // Ignore send failure on error path
    }
  }
}

/**
 * List active WhatsApp sessions for a business.
 */
export async function listSessions(businessId: string): Promise<unknown[]> {
  return prisma.whatsAppSession.findMany({
    where: { businessId },
    orderBy: { lastActivity: 'desc' },
    include: {
      messages: {
        orderBy: { createdAt: 'desc' },
        take: 1,
      },
    },
  });
}

/**
 * Send a template message to a phone via WhatsApp.
 */
export async function sendTemplate(
  phone: string,
  templateId: string,
  params: Record<string, string>,
): Promise<void> {
  await gupshup.sendTemplate(phone, templateId, params);
}

/**
 * Broadcast a text message to a list of phones.
 */
export async function broadcastMessage(
  businessId: string,
  phones: string[],
  message: string,
): Promise<{ sent: number; failed: number }> {
  let sent = 0;
  let failed = 0;

  for (const phone of phones) {
    try {
      await gupshup.sendText(phone, message);
      sent++;

      // Log outbound
      const session = await prisma.whatsAppSession.findUnique({ where: { phone } });
      if (session) {
        await logMessage(session.id, 'OUTBOUND', message, businessId);
      }
    } catch (error) {
      console.error(`[WhatsApp] Broadcast failed for ${phone}:`, error);
      failed++;
    }
  }

  return { sent, failed };
}
