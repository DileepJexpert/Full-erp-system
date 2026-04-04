import type { FastifyInstance } from 'fastify';
import * as templatesService from './templates.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function templateRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // Templates
  app.post('/templates', {
    schema: { tags: ['Templates'], summary: 'Create menu template', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await templatesService.createTemplate(request.tenant.businessId, request.body as any);
      return reply.code(201).send(result);
    },
  });

  app.get('/templates', {
    schema: { tags: ['Templates'], summary: 'List menu templates', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await templatesService.getTemplates(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/templates/:id', {
    schema: { tags: ['Templates'], summary: 'Get template by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await templatesService.getTemplateById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/templates/:id', {
    schema: { tags: ['Templates'], summary: 'Update template', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await templatesService.updateTemplate(request.tenant.businessId, id, request.body as any);
      return reply.send(result);
    },
  });

  app.delete('/templates/:id', {
    schema: { tags: ['Templates'], summary: 'Delete template', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await templatesService.deleteTemplate(request.tenant.businessId, id);
      return reply.code(204).send();
    },
  });

  // Seasons
  app.post('/seasons', {
    schema: { tags: ['Templates'], summary: 'Create season', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await templatesService.createSeason(request.tenant.businessId, request.body as any);
      return reply.code(201).send(result);
    },
  });

  app.get('/seasons', {
    schema: { tags: ['Templates'], summary: 'List seasons', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await templatesService.getSeasons(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.post('/seasons/:id/activate', {
    schema: { tags: ['Templates'], summary: 'Activate season', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await templatesService.activateSeason(request.tenant.businessId, id);
      return reply.send(result);
    },
  });
}
