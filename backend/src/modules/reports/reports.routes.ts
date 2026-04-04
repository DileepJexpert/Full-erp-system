import type { FastifyInstance } from 'fastify';
import * as reportsService from './reports.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function reportRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);
  app.addHook('preHandler', authorize('OWNER', 'MANAGER'));

  app.get('/reports/pnl', {
    schema: { tags: ['Reports'], summary: 'Profit & Loss report', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { startDate, endDate } = request.query as { startDate?: string; endDate?: string };
      const end = endDate ? new Date(endDate) : new Date();
      const start = startDate ? new Date(startDate) : new Date(end.getFullYear(), end.getMonth(), 1);
      const result = await reportsService.getPnlReport(request.tenant.businessId, start, end);
      return reply.send(result);
    },
  });

  app.get('/reports/gst', {
    schema: { tags: ['Reports'], summary: 'GST report', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { startDate, endDate } = request.query as { startDate?: string; endDate?: string };
      const end = endDate ? new Date(endDate) : new Date();
      const start = startDate ? new Date(startDate) : new Date(end.getFullYear(), end.getMonth(), 1);
      const result = await reportsService.getGstReport(request.tenant.businessId, start, end);
      return reply.send(result);
    },
  });

  app.get('/reports/bills/csv', {
    schema: { tags: ['Reports'], summary: 'Export bills as CSV', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { startDate, endDate } = request.query as { startDate?: string; endDate?: string };
      const end = endDate ? new Date(endDate) : new Date();
      const start = startDate ? new Date(startDate) : new Date(end.getFullYear(), end.getMonth(), 1);
      const csv = await reportsService.exportBillsCsv(request.tenant.businessId, start, end);
      return reply.header('Content-Type', 'text/csv').header('Content-Disposition', 'attachment; filename=bills.csv').send(csv);
    },
  });
}
