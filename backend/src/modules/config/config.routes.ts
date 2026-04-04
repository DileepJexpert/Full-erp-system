import type { FastifyInstance } from 'fastify';
import * as configService from './config.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function configRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.get('/config', {
    schema: { tags: ['Config'], summary: 'Get business configuration', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await configService.getBusinessConfig(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.put('/config', {
    schema: { tags: ['Config'], summary: 'Update business configuration', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const result = await configService.updateBusinessConfig(request.tenant.businessId, request.body as Record<string, unknown>);
      return reply.send(result);
    },
  });

  app.get('/config/features', {
    schema: { tags: ['Config'], summary: 'Get feature flags', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await configService.getFeatureFlags(request.tenant.businessId);
      return reply.send(result);
    },
  });
}
