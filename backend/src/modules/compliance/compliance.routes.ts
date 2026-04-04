import type { FastifyInstance } from 'fastify';
import * as complianceService from './compliance.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function complianceRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/compliance', {
    schema: { tags: ['Compliance'], summary: 'Add compliance document', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await complianceService.createDoc(request.tenant.businessId, request.body as any);
      return reply.code(201).send(result);
    },
  });

  app.get('/compliance', {
    schema: { tags: ['Compliance'], summary: 'List compliance documents', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await complianceService.getDocs(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/compliance/:id', {
    schema: { tags: ['Compliance'], summary: 'Get compliance document', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await complianceService.getDocById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/compliance/:id', {
    schema: { tags: ['Compliance'], summary: 'Update compliance document', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await complianceService.updateDoc(request.tenant.businessId, id, request.body as any);
      return reply.send(result);
    },
  });

  app.delete('/compliance/:id', {
    schema: { tags: ['Compliance'], summary: 'Delete compliance document', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await complianceService.deleteDoc(request.tenant.businessId, id);
      return reply.code(204).send();
    },
  });
}
