import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import * as transferService from './transfers.service.js';

const createTransferSchema = z.object({
  fromLocationId: z.string(),
  toLocationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  notes: z.string().optional(),
  items: z.array(z.object({
    itemId: z.string(),
    quantity: z.number().positive(),
  })).min(1),
});

const transferListQuerySchema = z.object({
  status: z.string().optional(),
  fromLocationId: z.string().optional(),
  toLocationId: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export async function transferRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /transfers/create ──
  app.post('/transfers/create', {
    schema: {
      tags: ['Stock Transfers'],
      summary: 'Create a stock transfer',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          fromLocationId: { type: 'string' },
          toLocationId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          notes: { type: 'string' },
          items: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              properties: {
                itemId: { type: 'string' },
                quantity: { type: 'number', exclusiveMinimum: 0 },
              },
              required: ['itemId', 'quantity'],
            },
          },
        },
        required: ['fromLocationId', 'toLocationId', 'date', 'items'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const body = createTransferSchema.parse(request.body);
      const result = await transferService.createTransfer(businessId, body);
      return reply.code(201).send(result);
    },
  });

  // ── GET /transfers/list ──
  app.get('/transfers/list', {
    schema: {
      tags: ['Stock Transfers'],
      summary: 'List stock transfers',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          status: { type: 'string' },
          fromLocationId: { type: 'string' },
          toLocationId: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
          offset: { type: 'integer', minimum: 0, default: 0 },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = transferListQuerySchema.parse(request.query);

      const where: Record<string, unknown> = { businessId };
      if (query.status) where.status = query.status;
      if (query.fromLocationId) where.fromLocationId = query.fromLocationId;
      if (query.toLocationId) where.toLocationId = query.toLocationId;

      const [data, total] = await Promise.all([
        prisma.stockTransfer.findMany({
          where,
          include: { items: true },
          orderBy: { createdAt: 'desc' },
          take: query.limit,
          skip: query.offset,
        }),
        prisma.stockTransfer.count({ where }),
      ]);

      return reply.send({ data, total });
    },
  });

  // ── PUT /transfers/:id/complete ──
  app.put('/transfers/:id/complete', {
    schema: {
      tags: ['Stock Transfers'],
      summary: 'Complete a stock transfer (atomic stock update)',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId, userId } = request.tenant;
      const { id } = request.params as { id: string };
      const result = await transferService.completeTransfer(businessId, id, userId);
      return reply.send(result);
    },
  });

  // ── PUT /transfers/:id/cancel ──
  app.put('/transfers/:id/cancel', {
    schema: {
      tags: ['Stock Transfers'],
      summary: 'Cancel a pending stock transfer',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };
      const result = await transferService.cancelTransfer(businessId, id);
      return reply.send(result);
    },
  });
}
