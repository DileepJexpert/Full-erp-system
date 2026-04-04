import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const submitFeedbackSchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().optional(),
  locationId: z.string(),
  customerId: z.string().optional(),
  channel: z.string().default('WEB'),
});

const feedbackListQuerySchema = z.object({
  locationId: z.string().optional(),
  rating: z.coerce.number().int().min(1).max(5).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

const npsSummaryQuerySchema = z.object({
  locationId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

export async function feedbackRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /feedback/submit (public - no auth) ──
  app.post('/feedback/submit', {
    schema: {
      tags: ['Feedback'],
      summary: 'Submit customer feedback (public, no auth required)',
      body: {
        type: 'object',
        properties: {
          rating: { type: 'integer', minimum: 1, maximum: 5 },
          comment: { type: 'string' },
          locationId: { type: 'string' },
          customerId: { type: 'string' },
          channel: { type: 'string', default: 'WEB' },
        },
        required: ['rating', 'locationId'],
      },
    },
    handler: async (request, reply) => {
      const body = submitFeedbackSchema.parse(request.body);

      // We need the businessId from the location since this is unauthenticated
      const location = await prisma.location.findUnique({
        where: { id: body.locationId },
        select: { businessId: true },
      });

      if (!location) {
        return reply.code(404).send({ error: 'Location not found' });
      }

      const feedback = await prisma.customerFeedback.create({
        data: {
          rating: body.rating,
          comment: body.comment ?? null,
          channel: body.channel,
          locationId: body.locationId,
          customerId: body.customerId ?? null,
          businessId: location.businessId,
        },
      });

      return reply.code(201).send(feedback);
    },
  });

  // ── GET /feedback/list ──
  app.get('/feedback/list', {
    schema: {
      tags: ['Feedback'],
      summary: 'List customer feedback (Owner only)',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          rating: { type: 'integer', minimum: 1, maximum: 5 },
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
      const query = feedbackListQuerySchema.parse(request.query);

      const where: Record<string, unknown> = { businessId };
      if (query.locationId) where.locationId = query.locationId;
      if (query.rating) where.rating = query.rating;

      if (query.startDate || query.endDate) {
        const dateFilter: Record<string, Date> = {};
        if (query.startDate) dateFilter.gte = new Date(query.startDate);
        if (query.endDate) dateFilter.lte = new Date(query.endDate);
        where.createdAt = dateFilter;
      }

      const [data, total] = await Promise.all([
        prisma.customerFeedback.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          take: query.limit,
          skip: query.offset,
        }),
        prisma.customerFeedback.count({ where }),
      ]);

      return reply.send({ data, total });
    },
  });

  // ── GET /feedback/nps-summary ──
  app.get('/feedback/nps-summary', {
    schema: {
      tags: ['Feedback'],
      summary: 'NPS score calculation per location',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          startDate: { type: 'string' },
          endDate: { type: 'string' },
        },
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = npsSummaryQuerySchema.parse(request.query);

      const where: Record<string, unknown> = { businessId };
      if (query.locationId) where.locationId = query.locationId;

      if (query.startDate || query.endDate) {
        const dateFilter: Record<string, Date> = {};
        if (query.startDate) dateFilter.gte = new Date(query.startDate);
        if (query.endDate) dateFilter.lte = new Date(query.endDate);
        where.createdAt = dateFilter;
      }

      const allFeedback = await prisma.customerFeedback.findMany({
        where,
        select: { locationId: true, rating: true },
      });

      // Group by location
      const byLocation = new Map<string, number[]>();
      for (const fb of allFeedback) {
        const ratings = byLocation.get(fb.locationId) ?? [];
        ratings.push(fb.rating);
        byLocation.set(fb.locationId, ratings);
      }

      const summary = Array.from(byLocation.entries()).map(([locationId, ratings]) => {
        const total = ratings.length;
        const promoters = ratings.filter(r => r >= 4).length;   // 4-5
        const detractors = ratings.filter(r => r <= 2).length;   // 1-2
        const passives = total - promoters - detractors;          // 3

        const nps = total > 0
          ? Math.round(((promoters - detractors) / total) * 100)
          : 0;

        return {
          locationId,
          totalResponses: total,
          promoters,
          passives,
          detractors,
          nps,
          averageRating: total > 0
            ? Math.round((ratings.reduce((a, b) => a + b, 0) / total) * 100) / 100
            : 0,
        };
      });

      return reply.send({ data: summary });
    },
  });
}
