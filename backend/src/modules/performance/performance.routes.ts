import type { FastifyInstance } from 'fastify';
import * as performanceService from './performance.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function performanceRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.get('/performance', {
    schema: { tags: ['Performance'], summary: 'Get operator performance scores', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { startDate, endDate } = request.query as { startDate?: string; endDate?: string };
      const end = endDate ? new Date(endDate) : new Date();
      const start = startDate ? new Date(startDate) : new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);
      const result = await performanceService.computePerformanceScores(
        request.tenant.businessId, start, end,
      );
      return reply.send(result);
    },
  });
}
