import type { FastifyInstance } from 'fastify';
import { createReconciliationSchema, reconQuerySchema } from './reconciliation.schema.js';
import * as reconciliationService from './reconciliation.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { requireFeature } from '../../middleware/featureGuard.js';

export async function reconciliationRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);
  app.addHook('preHandler', requireFeature('enableReconciliation'));

  app.post('/reconciliation', {
    schema: {
      tags: ['Reconciliation'],
      summary: 'Create a reconciliation for a dispatch',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          dispatchId: { type: 'string' },
          locationId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          items: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              properties: {
                itemId: { type: 'string' },
                sold: { type: 'integer', minimum: 0 },
                returned: { type: 'integer', minimum: 0 },
              },
              required: ['itemId', 'sold', 'returned'],
            },
          },
          notes: { type: 'string' },
        },
        required: ['dispatchId', 'locationId', 'date', 'items'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = createReconciliationSchema.parse(request.body);
      const result = await reconciliationService.createReconciliation(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/reconciliation', {
    schema: {
      tags: ['Reconciliation'],
      summary: 'List reconciliations with pagination and filtering',
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
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const query = reconQuerySchema.parse(request.query);
      const result = await reconciliationService.getReconciliations(
        request.tenant.businessId,
        query,
      );
      return reply.send(result);
    },
  });

  app.get('/reconciliation/:id', {
    schema: {
      tags: ['Reconciliation'],
      summary: 'Get a single reconciliation by ID',
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
      const result = await reconciliationService.getReconciliationById(
        request.tenant.businessId,
        id,
      );
      return reply.send(result);
    },
  });
}
