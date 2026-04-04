import type { FastifyInstance } from 'fastify';
import { createBillSchema, billQuerySchema } from './billing.schema.js';
import * as billingService from './billing.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function billingRoutes(app: FastifyInstance): Promise<void> {
  app.post('/billing', {
    schema: {
      tags: ['Billing'],
      summary: 'Create a new bill',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          items: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              properties: {
                itemId: { type: 'string' },
                quantity: { type: 'integer', minimum: 1 },
                unitPrice: { type: 'number', exclusiveMinimum: 0 },
              },
              required: ['itemId', 'quantity', 'unitPrice'],
            },
          },
          paymentMode: { type: 'string', enum: ['CASH', 'UPI', 'MIXED'] },
          cashAmount: { type: 'number', minimum: 0 },
          upiAmount: { type: 'number', minimum: 0 },
          upiTransactionRef: { type: 'string' },
          orderSource: { type: 'string', enum: ['WALK_IN', 'SWIGGY', 'ZOMATO', 'PHONE_ORDER', 'OTHER'] },
          aggregatorOrderId: { type: 'string' },
          aggregatorCommission: { type: 'number', minimum: 0 },
          customerPhone: { type: 'string' },
          customerName: { type: 'string' },
          loyaltyPointsRedeemed: { type: 'integer', minimum: 0 },
          notes: { type: 'string' },
        },
        required: ['locationId', 'date', 'items'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = createBillSchema.parse(request.body);
      const result = await billingService.createBill(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/billing', {
    schema: {
      tags: ['Billing'],
      summary: 'List bills with pagination and filtering',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          date: { type: 'string' },
          startDate: { type: 'string' },
          endDate: { type: 'string' },
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const query = billQuerySchema.parse(request.query);
      const result = await billingService.getBills(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/billing/:id', {
    schema: {
      tags: ['Billing'],
      summary: 'Get a single bill by ID',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await billingService.getBillById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });
}
