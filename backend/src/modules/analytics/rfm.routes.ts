import type { FastifyInstance } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { BadRequestError } from '../../utils/errors.js';
import { calculateRFMSegments, type CustomerSegment } from './rfm.service.js';

const VALID_SEGMENTS = ['Champions', 'Loyal', 'AtRisk', 'New', 'Dormant'] as const;

export async function rfmRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // ─── GET /segments ──────────────────────────────────────────
  app.get('/segments', {
    schema: {
      tags: ['RFM Segments'],
      summary: 'Get RFM segments with customer lists',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const segments = await calculateRFMSegments(request.tenant.businessId);
      return reply.send(segments);
    },
  });

  // ─── GET /segments/:segment ─────────────────────────────────
  app.get('/segments/:segment', {
    schema: {
      tags: ['RFM Segments'],
      summary: 'Get customers in a specific segment',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: {
          segment: { type: 'string', enum: [...VALID_SEGMENTS] },
        },
        required: ['segment'],
      },
    },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const { segment } = request.params as { segment: string };

      if (!VALID_SEGMENTS.includes(segment as CustomerSegment['segment'])) {
        throw new BadRequestError(
          `Invalid segment "${segment}". Valid segments: ${VALID_SEGMENTS.join(', ')}`,
        );
      }

      const segments = await calculateRFMSegments(request.tenant.businessId);
      const match = segments.find((s) => s.segment === segment);

      return reply.send(match ?? { segment, count: 0, avgSpend: 0, customers: [] });
    },
  });
}
