import type { FastifyInstance } from 'fastify';
import * as alertsService from './alerts.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { z } from 'zod';

const alertQuerySchema = z.object({
  status: z.enum(['UNREAD', 'READ', 'INVESTIGATING', 'RESOLVED', 'DISMISSED']).optional(),
  type: z.string().optional(),
  severity: z.enum(['INFO', 'WARNING', 'CRITICAL']).optional(),
  locationId: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export async function alertRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.get('/alerts', {
    schema: { tags: ['Alerts'], summary: 'List alerts', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const query = alertQuerySchema.parse(request.query);
      const result = await alertsService.getAlerts(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/alerts/:id', {
    schema: { tags: ['Alerts'], summary: 'Get alert by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await alertsService.getAlertById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.patch('/alerts/:id/status', {
    schema: { tags: ['Alerts'], summary: 'Update alert status', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const { status } = request.body as { status: string };
      const result = await alertsService.updateAlertStatus(request.tenant.businessId, id, status);
      return reply.send(result);
    },
  });

  app.get('/alerts/summary', {
    schema: { tags: ['Alerts'], summary: 'Get alert summary counts', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await alertsService.getAlertSummary(request.tenant.businessId);
      return reply.send(result);
    },
  });
}
