import { prisma } from '../lib/prisma.js';

/**
 * Daily 7 AM: find RecurringInvoices where nextDueDate = today,
 * create Bill for each, update nextDueDate.
 */
export async function runRecurringInvoicesJob(): Promise<void> {
  console.log('[JOB] recurring-invoices: starting...');

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayEnd = new Date(today);
  todayEnd.setHours(23, 59, 59, 999);

  // Find all active recurring invoices due today
  const dueInvoices = await prisma.recurringInvoice.findMany({
    where: {
      isActive: true,
      nextDueDate: { gte: today, lte: todayEnd },
    },
  });

  console.log(`[JOB] recurring-invoices: found ${dueInvoices.length} invoices due today`);

  let createdCount = 0;
  let errorCount = 0;

  for (const invoice of dueInvoices) {
    try {
      const items = invoice.items as Array<{
        itemId: string;
        quantity: number;
        unitPrice: number;
      }>;

      if (!items || items.length === 0) {
        console.warn(`[JOB] recurring-invoices: invoice ${invoice.id} has no items, skipping`);
        continue;
      }

      // Find the business to get an operator (owner) for the bill
      const owner = await prisma.user.findFirst({
        where: { businessId: invoice.businessId, role: 'OWNER', isActive: true },
        select: { id: true },
      });

      if (!owner) {
        console.error(`[JOB] recurring-invoices: no active OWNER found for business ${invoice.businessId}`);
        errorCount++;
        continue;
      }

      // Determine location (use recurringInvoice's locationId or first active location)
      let locationId = invoice.locationId;
      if (!locationId) {
        const firstLocation = await prisma.location.findFirst({
          where: { businessId: invoice.businessId, isActive: true },
          select: { id: true },
        });
        if (!firstLocation) {
          console.error(`[JOB] recurring-invoices: no active location for business ${invoice.businessId}`);
          errorCount++;
          continue;
        }
        locationId = firstLocation.id;
      }

      // Calculate bill totals
      const billItems = items.map((item) => ({
        itemId: item.itemId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotal: Math.round(item.quantity * item.unitPrice * 100) / 100,
      }));
      const subtotal = billItems.reduce((sum, i) => sum + i.lineTotal, 0);

      // Create the bill
      await prisma.bill.create({
        data: {
          date: today,
          subtotal,
          total: invoice.totalAmount,
          paymentMode: 'CASH',
          cashAmount: invoice.totalAmount,
          netRevenue: invoice.totalAmount,
          orderSource: 'OTHER',
          notes: `Auto-generated from recurring invoice ${invoice.id}`,
          businessId: invoice.businessId,
          locationId,
          operatorId: owner.id,
          customerId: invoice.customerId || undefined,
          items: {
            create: billItems,
          },
        },
      });

      // Calculate next due date based on frequency
      const nextDueDate = calculateNextDueDate(today, invoice.frequency);

      await prisma.recurringInvoice.update({
        where: { id: invoice.id },
        data: { nextDueDate },
      });

      createdCount++;
      console.log(`[JOB] recurring-invoices: created bill for invoice ${invoice.id}, next due: ${nextDueDate.toISOString().split('T')[0]}`);
    } catch (err) {
      errorCount++;
      console.error(`[JOB] recurring-invoices: failed for invoice ${invoice.id}:`, err);
    }
  }

  console.log(`[JOB] recurring-invoices: completed. ${createdCount} bills created, ${errorCount} errors.`);
}

function calculateNextDueDate(currentDate: Date, frequency: string): Date {
  const next = new Date(currentDate);

  switch (frequency) {
    case 'daily':
      next.setDate(next.getDate() + 1);
      break;

    case 'weekly':
      next.setDate(next.getDate() + 7);
      break;

    case 'biweekly':
      next.setDate(next.getDate() + 14);
      break;

    case 'monthly':
      next.setMonth(next.getMonth() + 1);
      break;

    case 'quarterly':
      next.setMonth(next.getMonth() + 3);
      break;

    case 'yearly':
      next.setFullYear(next.getFullYear() + 1);
      break;

    default:
      // Default to monthly
      next.setMonth(next.getMonth() + 1);
      break;
  }

  return next;
}
