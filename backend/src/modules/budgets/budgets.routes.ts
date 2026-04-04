import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import * as budgetService from './budgets.service.js';

const upsertBudgetSchema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/),
  locationId: z.string(),
  revenueTarget: z.number().min(0),
  cogsLimit: z.number().min(0),
  expenseLimit: z.number().min(0),
  salaryBudget: z.number().min(0),
  profitTarget: z.number(),
});

const budgetListQuerySchema = z.object({
  locationId: z.string().optional(),
  month: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

const varianceQuerySchema = z.object({
  locationId: z.string().optional(),
});

export async function budgetRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /budgets ──
  app.post('/budgets', {
    schema: {
      tags: ['Budgets'],
      summary: 'Create or update a budget for a location and month',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          month: { type: 'string', pattern: '^\\d{4}-\\d{2}$' },
          locationId: { type: 'string' },
          revenueTarget: { type: 'number', minimum: 0 },
          cogsLimit: { type: 'number', minimum: 0 },
          expenseLimit: { type: 'number', minimum: 0 },
          salaryBudget: { type: 'number', minimum: 0 },
          profitTarget: { type: 'number' },
        },
        required: ['month', 'locationId', 'revenueTarget', 'cogsLimit', 'expenseLimit', 'salaryBudget', 'profitTarget'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const body = upsertBudgetSchema.parse(request.body);

      const budget = await prisma.budget.upsert({
        where: {
          locationId_month: {
            locationId: body.locationId,
            month: body.month,
          },
        },
        create: {
          ...body,
          businessId,
        },
        update: {
          revenueTarget: body.revenueTarget,
          cogsLimit: body.cogsLimit,
          expenseLimit: body.expenseLimit,
          salaryBudget: body.salaryBudget,
          profitTarget: body.profitTarget,
        },
      });

      return reply.code(201).send(budget);
    },
  });

  // ── GET /budgets ──
  app.get('/budgets', {
    schema: {
      tags: ['Budgets'],
      summary: 'List budgets',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          month: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
          offset: { type: 'integer', minimum: 0, default: 0 },
        },
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = budgetListQuerySchema.parse(request.query);

      const where: Record<string, unknown> = { businessId };
      if (query.locationId) where.locationId = query.locationId;
      if (query.month) where.month = query.month;

      const [data, total] = await Promise.all([
        prisma.budget.findMany({
          where,
          orderBy: { month: 'desc' },
          take: query.limit,
          skip: query.offset,
        }),
        prisma.budget.count({ where }),
      ]);

      return reply.send({ data, total });
    },
  });

  // ── GET /budgets/:month/variance ──
  app.get('/budgets/:month/variance', {
    schema: {
      tags: ['Budgets'],
      summary: 'Budget vs actual variance for a month',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { month: { type: 'string' } },
        required: ['month'],
      },
      querystring: {
        type: 'object',
        properties: { locationId: { type: 'string' } },
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { month } = request.params as { month: string };
      const query = varianceQuerySchema.parse(request.query);

      const result = await budgetService.calculateVariance(businessId, month, query.locationId);
      return reply.send({ data: result });
    },
  });
}
