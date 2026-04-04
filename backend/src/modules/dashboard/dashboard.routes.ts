import type { FastifyInstance } from 'fastify';
import * as dashboardService from './dashboard.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function dashboardRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.get('/dashboard/overview', {
    schema: { tags: ['Dashboard'], summary: 'Get dashboard overview', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await dashboardService.getOverview(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/dashboard/locations', {
    schema: { tags: ['Dashboard'], summary: 'Get per-location statistics', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { startDate, endDate } = request.query as { startDate?: string; endDate?: string };
      const end = endDate ? new Date(endDate) : new Date();
      const start = startDate ? new Date(startDate) : new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);
      const result = await dashboardService.getLocationStats(request.tenant.businessId, start, end);
      return reply.send(result);
    },
  });
}
