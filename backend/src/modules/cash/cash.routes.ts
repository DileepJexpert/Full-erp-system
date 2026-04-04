import type { FastifyInstance } from 'fastify';
import { recordCashSchema, cashQuerySchema } from './cash.schema.js';
import * as cashService from './cash.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function cashRoutes(app: FastifyInstance): Promise<void> {
  app.post('/cash', {
    schema: {
      tags: ['Cash'],
      summary: 'Record a cash collection',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          operatorId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          expectedCash: { type: 'number', minimum: 0 },
          actualCollected: { type: 'number', minimum: 0 },
          depositedAmount: { type: 'number', minimum: 0 },
          bankRef: { type: 'string' },
          notes: { type: 'string' },
        },
        required: ['locationId', 'operatorId', 'date', 'expectedCash', 'actualCollected'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = recordCashSchema.parse(request.body);
      const result = await cashService.recordCash(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/cash', {
    schema: {
      tags: ['Cash'],
      summary: 'List cash collections with pagination and filtering',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          operatorId: { type: 'string' },
          startDate: { type: 'string' },
          endDate: { type: 'string' },
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const query = cashQuerySchema.parse(request.query);
      const result = await cashService.getCashCollections(
        request.tenant.businessId,
        query,
      );
      return reply.send(result);
    },
  });

  app.get('/cash/:id', {
    schema: {
      tags: ['Cash'],
      summary: 'Get a single cash collection by ID',
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
      const result = await cashService.getCashById(
        request.tenant.businessId,
        id,
      );
      return reply.send(result);
    },
  });
}
