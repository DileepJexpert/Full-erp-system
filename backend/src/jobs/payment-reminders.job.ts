import { prisma } from '../lib/prisma.js';
import type { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/authenticate.js';
import { authorize } from '../middleware/authorize.js';

interface ReminderSummary {
  creditReminders: number;
  invoiceReminders: number;
}

export async function runPaymentReminders(businessId?: string): Promise<ReminderSummary> {
  console.log('[JOB] payment-reminders: starting...');

  const now = new Date();
  let creditReminders = 0;
  let invoiceReminders = 0;

  // Determine which businesses to process
  const businessFilter = businessId ? { id: businessId } : {};
  const businesses = await prisma.business.findMany({
    where: businessFilter,
    select: { id: true },
  });

  for (const business of businesses) {
    try {
      // 1. Credit ledger: customers with creditBalance > 0 and last PAYMENT_RECEIVED > 7 days ago
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

      const customersWithCredit = await prisma.customer.findMany({
        where: {
          businessId: business.id,
          creditBalance: { gt: 0 },
        },
        select: { id: true, phone: true, name: true, creditBalance: true },
      });

      for (const customer of customersWithCredit) {
        // Check if last PAYMENT_RECEIVED was more than 7 days ago
        const lastPayment = await prisma.creditTransaction.findFirst({
          where: {
            businessId: business.id,
            customerId: customer.id,
            type: 'PAYMENT_RECEIVED',
          },
          orderBy: { date: 'desc' },
          select: { date: true },
        });

        // Send reminder if no payment ever, or last payment was > 7 days ago
        if (!lastPayment || lastPayment.date < sevenDaysAgo) {
          console.log(
            `[JOB] payment-reminders: Credit reminder for customer ${customer.id} ` +
            `(${customer.name ?? customer.phone}), balance: ${customer.creditBalance}`,
          );
          creditReminders++;
        }
      }

      // 2. Recurring invoices: active with nextDueDate within 3 days
      const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
      const today = new Date(now);
      today.setHours(0, 0, 0, 0);

      const upcomingInvoices = await prisma.recurringInvoice.findMany({
        where: {
          businessId: business.id,
          isActive: true,
          nextDueDate: { gte: today, lte: threeDaysFromNow },
        },
        select: { id: true, customerId: true, totalAmount: true, nextDueDate: true },
      });

      for (const invoice of upcomingInvoices) {
        console.log(
          `[JOB] payment-reminders: Invoice reminder for recurring invoice ${invoice.id}, ` +
          `amount: ${invoice.totalAmount}, due: ${invoice.nextDueDate.toISOString().split('T')[0]}`,
        );
        invoiceReminders++;
      }
    } catch (err) {
      console.error(`[JOB] payment-reminders: error processing business ${business.id}:`, err);
    }
  }

  console.log(
    `[JOB] payment-reminders: completed. ${creditReminders} credit reminders, ${invoiceReminders} invoice reminders.`,
  );

  return { creditReminders, invoiceReminders };
}

/**
 * Route plugin for manually triggering and viewing payment reminders.
 */
export async function paymentReminderRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // POST /reminders/run - manually trigger reminders
  app.post('/reminders/run', {
    schema: { tags: ['Reminders'], summary: 'Manually trigger payment reminders', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const result = await runPaymentReminders(request.tenant.businessId);
      return reply.send(result);
    },
  });

  // GET /reminders/pending - list pending reminders
  app.get('/reminders/pending', {
    schema: { tags: ['Reminders'], summary: 'List pending payment reminders', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const now = new Date();
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
      const today = new Date(now);
      today.setHours(0, 0, 0, 0);

      const businessId = request.tenant.businessId;

      // Get customers with outstanding credit and no recent payment
      const customersWithCredit = await prisma.customer.findMany({
        where: {
          businessId,
          creditBalance: { gt: 0 },
        },
        select: { id: true, phone: true, name: true, creditBalance: true },
      });

      const creditReminders = [];
      for (const customer of customersWithCredit) {
        const lastPayment = await prisma.creditTransaction.findFirst({
          where: {
            businessId,
            customerId: customer.id,
            type: 'PAYMENT_RECEIVED',
          },
          orderBy: { date: 'desc' },
          select: { date: true },
        });

        if (!lastPayment || lastPayment.date < sevenDaysAgo) {
          creditReminders.push({
            type: 'CREDIT_REMINDER' as const,
            customerId: customer.id,
            customerName: customer.name,
            customerPhone: customer.phone,
            creditBalance: customer.creditBalance,
            lastPaymentDate: lastPayment?.date ?? null,
          });
        }
      }

      // Get upcoming recurring invoices
      const upcomingInvoices = await prisma.recurringInvoice.findMany({
        where: {
          businessId,
          isActive: true,
          nextDueDate: { gte: today, lte: threeDaysFromNow },
        },
        select: { id: true, customerId: true, totalAmount: true, nextDueDate: true, frequency: true },
      });

      const invoiceReminders = upcomingInvoices.map((inv) => ({
        type: 'INVOICE_REMINDER' as const,
        recurringInvoiceId: inv.id,
        customerId: inv.customerId,
        totalAmount: inv.totalAmount,
        nextDueDate: inv.nextDueDate,
        frequency: inv.frequency,
      }));

      return reply.send({
        creditReminders,
        invoiceReminders,
        summary: {
          creditReminders: creditReminders.length,
          invoiceReminders: invoiceReminders.length,
        },
      });
    },
  });
}
