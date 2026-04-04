import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const auditQuerySchema = z.object({
  entityType: z.string().optional(),
  entityId: z.string().optional(),
  userId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export async function auditRoutes(app: FastifyInstance): Promise<void> {
  app.get('/audit/logs', {
    schema: {
      tags: ['Audit'],
      summary: 'List audit logs with filtering and pagination',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          entityType: { type: 'string' },
          entityId: { type: 'string' },
          userId: { type: 'string' },
          startDate: { type: 'string' },
          endDate: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
          offset: { type: 'integer', minimum: 0, default: 0 },
        },
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = auditQuerySchema.parse(request.query);

      const where: Record<string, unknown> = { businessId };

      if (query.entityType) where.entityType = query.entityType;
      if (query.entityId) where.entityId = query.entityId;
      if (query.userId) where.userId = query.userId;

      if (query.startDate || query.endDate) {
        const dateFilter: Record<string, Date> = {};
        if (query.startDate) dateFilter.gte = new Date(query.startDate);
        if (query.endDate) dateFilter.lte = new Date(query.endDate);
        where.createdAt = dateFilter;
      }

      const [logs, total] = await Promise.all([
        prisma.auditLog.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          take: query.limit,
          skip: query.offset,
        }),
        prisma.auditLog.count({ where }),
      ]);

      return reply.send({ data: logs, total, limit: query.limit, offset: query.offset });
    },
  });
}
