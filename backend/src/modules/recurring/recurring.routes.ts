import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';

const createRecurringSchema = z.object({
  customerId: z.string(),
  items: z.array(z.object({
    itemId: z.string(),
    quantity: z.number().int().min(1),
    unitPrice: z.number().positive(),
  })).min(1),
  frequency: z.enum(['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY']),
  nextDueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  totalAmount: z.number().positive(),
  locationId: z.string().optional(),
});

const updateRecurringSchema = z.object({
  items: z.array(z.object({
    itemId: z.string(),
    quantity: z.number().int().min(1),
    unitPrice: z.number().positive(),
  })).min(1).optional(),
  frequency: z.enum(['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY']).optional(),
  nextDueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  totalAmount: z.number().positive().optional(),
  isActive: z.boolean().optional(),
});

export async function recurringRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /recurring/invoices ──
  app.post('/recurring/invoices', {
    schema: {
      tags: ['Recurring Invoices'],
      summary: 'Create a recurring invoice configuration',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          customerId: { type: 'string' },
          items: { type: 'array', minItems: 1 },
          frequency: { type: 'string', enum: ['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY'] },
          nextDueDate: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          totalAmount: { type: 'number', exclusiveMinimum: 0 },
          locationId: { type: 'string' },
        },
        required: ['customerId', 'items', 'frequency', 'nextDueDate', 'totalAmount'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const body = createRecurringSchema.parse(request.body);

      const invoice = await prisma.recurringInvoice.create({
        data: {
          customerId: body.customerId,
          items: body.items as any,
          frequency: body.frequency,
          nextDueDate: new Date(body.nextDueDate),
          totalAmount: body.totalAmount,
          locationId: body.locationId ?? null,
          businessId,
        },
      });

      return reply.code(201).send(invoice);
    },
  });

  // ── GET /recurring/invoices ──
  app.get('/recurring/invoices', {
    schema: {
      tags: ['Recurring Invoices'],
      summary: 'List recurring invoices',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;

      const invoices = await prisma.recurringInvoice.findMany({
        where: { businessId },
        orderBy: { createdAt: 'desc' },
      });

      return reply.send({ data: invoices });
    },
  });

  // ── PUT /recurring/invoices/:id ──
  app.put('/recurring/invoices/:id', {
    schema: {
      tags: ['Recurring Invoices'],
      summary: 'Update a recurring invoice configuration',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };
      const body = updateRecurringSchema.parse(request.body);

      const existing = await prisma.recurringInvoice.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('RecurringInvoice', id);

      const data: Record<string, unknown> = {};
      if (body.items !== undefined) data.items = body.items as any;
      if (body.frequency !== undefined) data.frequency = body.frequency;
      if (body.nextDueDate !== undefined) data.nextDueDate = new Date(body.nextDueDate);
      if (body.totalAmount !== undefined) data.totalAmount = body.totalAmount;
      if (body.isActive !== undefined) data.isActive = body.isActive;

      const updated = await prisma.recurringInvoice.update({
        where: { id },
        data,
      });

      return reply.send(updated);
    },
  });

  // ── DELETE /recurring/invoices/:id ──
  app.delete('/recurring/invoices/:id', {
    schema: {
      tags: ['Recurring Invoices'],
      summary: 'Deactivate a recurring invoice',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };

      const existing = await prisma.recurringInvoice.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('RecurringInvoice', id);

      const deactivated = await prisma.recurringInvoice.update({
        where: { id },
        data: { isActive: false },
      });

      return reply.send(deactivated);
    },
  });

  // ── POST /recurring/invoices/:id/generate-now ──
  app.post('/recurring/invoices/:id/generate-now', {
    schema: {
      tags: ['Recurring Invoices'],
      summary: 'Manually trigger bill generation from recurring invoice',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId, userId } = request.tenant;
      const { id } = request.params as { id: string };

      const recurring = await prisma.recurringInvoice.findFirst({
        where: { id, businessId },
      });
      if (!recurring) throw new NotFoundError('RecurringInvoice', id);
      if (!recurring.isActive) throw new BadRequestError('Recurring invoice is not active');

      const items = recurring.items as Array<{ itemId: string; quantity: number; unitPrice: number }>;

      // Generate a Bill from the recurring invoice config
      const bill = await prisma.bill.create({
        data: {
          date: new Date(),
          total: recurring.totalAmount,
          subtotal: recurring.totalAmount,
          businessId,
          locationId: recurring.locationId ?? '',
          operatorId: userId,
          customerId: recurring.customerId,
          notes: `Auto-generated from recurring invoice ${recurring.id}`,
          items: {
            create: items.map((item) => ({
              itemId: item.itemId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              lineTotal: item.quantity * item.unitPrice,
            })),
          },
        },
        include: { items: true },
      });

      // Advance the next due date based on frequency
      const nextDue = new Date(recurring.nextDueDate);
      switch (recurring.frequency) {
        case 'DAILY':
          nextDue.setDate(nextDue.getDate() + 1);
          break;
        case 'WEEKLY':
          nextDue.setDate(nextDue.getDate() + 7);
          break;
        case 'BIWEEKLY':
          nextDue.setDate(nextDue.getDate() + 14);
          break;
        case 'MONTHLY':
          nextDue.setMonth(nextDue.getMonth() + 1);
          break;
      }

      await prisma.recurringInvoice.update({
        where: { id },
        data: { nextDueDate: nextDue },
      });

      return reply.code(201).send({ bill, nextDueDate: nextDue.toISOString() });
    },
  });
}
