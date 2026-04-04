import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { getRedis } from '../../lib/redis.js';
import { BadRequestError } from '../../utils/errors.js';
import { askAdvisor } from './ai-advisor.service.js';
import { predictDemand } from './demand-prediction.service.js';
import { getInsights, dismissInsight } from './insight-generator.service.js';

// ── Zod schemas ──────────────────────────────────────────────────

const aiQuerySchema = z.object({
  question: z.string().min(3).max(2000),
});

const demandPredictionSchema = z.object({
  itemId: z.string().min(1),
  locationId: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
});

// ── Rate limiting helper ─────────────────────────────────────────

async function checkRateLimit(
  businessId: string,
  limit: number,
  windowSeconds: number,
): Promise<{ allowed: boolean; remaining: number }> {
  const redis = getRedis();
  const key = `ai:rate:${businessId}`;

  try {
    const current = await redis.incr(key);
    if (current === 1) {
      await redis.expire(key, windowSeconds);
    }

    return {
      allowed: current <= limit,
      remaining: Math.max(0, limit - current),
    };
  } catch {
    // If Redis is down, allow the request
    return { allowed: true, remaining: limit };
  }
}

// ── Routes ───────────────────────────────────────────────────────

export async function aiRoutes(app: FastifyInstance): Promise<void> {
  /**
   * POST /ai/query
   * Owner asks a business question. Rate limit: 10/hour per business.
   */
  app.post('/ai/query', {
    schema: {
      tags: ['AI'],
      summary: 'Ask AI advisor a business question',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          question: { type: 'string', minLength: 3, maxLength: 2000 },
        },
        required: ['question'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const body = aiQuerySchema.parse(request.body);
      const { businessId, userId } = request.tenant;

      // Rate limit: 10 queries per hour per business
      const { allowed, remaining } = await checkRateLimit(businessId, 10, 3600);
      reply.header('X-RateLimit-Remaining', remaining.toString());

      if (!allowed) {
        throw new BadRequestError(
          'Rate limit exceeded. Maximum 10 AI queries per hour. Please try again later.',
        );
      }

      const result = await askAdvisor(businessId, userId, body.question);

      return reply.send({
        answer: result.answer,
        tokensUsed: result.tokensUsed,
        latencyMs: result.latencyMs,
        toolsUsed: result.toolsUsed,
      });
    },
  });

  /**
   * POST /ai/predict-demand
   * Get demand prediction for a specific item + location + date.
   */
  app.post('/ai/predict-demand', {
    schema: {
      tags: ['AI'],
      summary: 'Predict demand for an item at a location on a date',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          itemId: { type: 'string' },
          locationId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
        },
        required: ['itemId', 'locationId', 'date'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = demandPredictionSchema.parse(request.body);
      const { businessId, userId } = request.tenant;

      const prediction = await predictDemand(
        businessId,
        userId,
        body.itemId,
        body.locationId,
        body.date,
      );

      return reply.send(prediction);
    },
  });

  /**
   * GET /ai/insights
   * Get active insight cards. Owner only.
   */
  app.get('/ai/insights', {
    schema: {
      tags: ['AI'],
      summary: 'Get active AI-generated insight cards',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const insights = await getInsights(request.tenant.businessId);
      return reply.send({ data: insights });
    },
  });

  /**
   * POST /ai/insights/:id/dismiss
   * Dismiss an insight card. Owner only.
   */
  app.post('/ai/insights/:id/dismiss', {
    schema: {
      tags: ['AI'],
      summary: 'Dismiss an insight card',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await dismissInsight(request.tenant.businessId, id);
      return reply.send({ status: 'dismissed' });
    },
  });
}
