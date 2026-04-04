import type { FastifyInstance } from 'fastify';
import * as locationsService from './locations.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function locationsRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/locations', {
    schema: { tags: ['Locations'], summary: 'Create a new location', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await locationsService.createLocation(
        request.tenant.businessId,
        request.body as Record<string, unknown> as any,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/locations', {
    schema: { tags: ['Locations'], summary: 'List all locations', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await locationsService.getLocations(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/locations/:id', {
    schema: { tags: ['Locations'], summary: 'Get location by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await locationsService.getLocationById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/locations/:id', {
    schema: { tags: ['Locations'], summary: 'Update location', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await locationsService.updateLocation(
        request.tenant.businessId,
        id,
        request.body as Record<string, unknown> as any,
      );
      return reply.send(result);
    },
  });

  app.delete('/locations/:id', {
    schema: { tags: ['Locations'], summary: 'Soft-delete location', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await locationsService.deleteLocation(request.tenant.businessId, id);
      return reply.code(204).send();
    },
  });
}
