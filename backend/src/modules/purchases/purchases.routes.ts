import type { FastifyInstance } from 'fastify';
import { createPurchaseSchema, purchaseQuerySchema, recordPaymentSchema } from './purchases.schema.js';
import * as purchasesService from './purchases.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function purchasesRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/purchases', {
    schema: { tags: ['Purchases'], summary: 'Create a new purchase', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = createPurchaseSchema.parse(request.body);
      const result = await purchasesService.createPurchase(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/purchases', {
    schema: { tags: ['Purchases'], summary: 'List purchases with filtering', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const query = purchaseQuerySchema.parse(request.query);
      const result = await purchasesService.getPurchases(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/purchases/:id', {
    schema: { tags: ['Purchases'], summary: 'Get purchase by ID', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await purchasesService.getPurchaseById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.post('/purchases/:id/payment', {
    schema: { tags: ['Purchases'], summary: 'Record payment against a purchase', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = recordPaymentSchema.parse(request.body);
      const result = await purchasesService.recordPayment(request.tenant.businessId, id, body);
      return reply.send(result);
    },
  });
}
