import type { FastifyInstance } from 'fastify';
import { createDispatchSchema, dispatchQuerySchema } from './dispatch.schema.js';
import * as dispatchService from './dispatch.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function dispatchRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/dispatch', {
    schema: { tags: ['Dispatch'], summary: 'Create a dispatch', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = createDispatchSchema.parse(request.body);
      const result = await dispatchService.createDispatch(
        request.tenant.businessId, request.tenant.userId, body,
      );
      return reply.code(201).send(result);
    },
  });

  app.post('/dispatch/:id/confirm', {
    schema: { tags: ['Dispatch'], summary: 'Confirm a dispatch', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await dispatchService.confirmDispatch(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.get('/dispatch', {
    schema: { tags: ['Dispatch'], summary: 'List dispatches', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const query = dispatchQuerySchema.parse(request.query);
      const result = await dispatchService.getDispatches(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/dispatch/:id', {
    schema: { tags: ['Dispatch'], summary: 'Get dispatch by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await dispatchService.getDispatchById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.get('/dispatch/prefill/:locationId', {
    schema: { tags: ['Dispatch'], summary: 'Get template prefill for location', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { locationId } = request.params as { locationId: string };
      const result = await dispatchService.prefillFromTemplate(request.tenant.businessId, locationId);
      return reply.send(result);
    },
  });
}
