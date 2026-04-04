import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { NotFoundError } from '../../utils/errors.js';
import * as automationService from './automation.service.js';

const createRuleSchema = z.object({
  name: z.string().min(1).max(255),
  trigger: z.enum([
    'REVENUE_BELOW', 'REVENUE_ABOVE', 'EXPENSE_ABOVE', 'STOCK_BELOW',
    'WASTAGE_ABOVE', 'CASH_SHORTAGE', 'LATE_RECONCILIATION', 'LATE_CHECKIN',
    'BILL_AMOUNT_ABOVE', 'CUSTOM',
  ]),
  triggerConfig: z.record(z.unknown()),
  action: z.enum(['SEND_WHATSAPP', 'SEND_PUSH', 'CREATE_ALERT', 'BLOCK_EXPENSE', 'AUTO_REMINDER']),
  actionConfig: z.record(z.unknown()),
  isActive: z.boolean().default(true),
});

const updateRuleSchema = z.object({
  name: z.string().min(1).max(255).optional(),
  trigger: z.enum([
    'REVENUE_BELOW', 'REVENUE_ABOVE', 'EXPENSE_ABOVE', 'STOCK_BELOW',
    'WASTAGE_ABOVE', 'CASH_SHORTAGE', 'LATE_RECONCILIATION', 'LATE_CHECKIN',
    'BILL_AMOUNT_ABOVE', 'CUSTOM',
  ]).optional(),
  triggerConfig: z.record(z.unknown()).optional(),
  action: z.enum(['SEND_WHATSAPP', 'SEND_PUSH', 'CREATE_ALERT', 'BLOCK_EXPENSE', 'AUTO_REMINDER']).optional(),
  actionConfig: z.record(z.unknown()).optional(),
  isActive: z.boolean().optional(),
});

const ruleListQuerySchema = z.object({
  isActive: z.enum(['true', 'false']).optional(),
  trigger: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export async function automationRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /automation/rules ──
  app.post('/automation/rules', {
    schema: {
      tags: ['Automation'],
      summary: 'Create an automation rule',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          trigger: { type: 'string' },
          triggerConfig: { type: 'object' },
          action: { type: 'string' },
          actionConfig: { type: 'object' },
          isActive: { type: 'boolean', default: true },
        },
        required: ['name', 'trigger', 'triggerConfig', 'action', 'actionConfig'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const body = createRuleSchema.parse(request.body);

      const rule = await prisma.automationRule.create({
        data: {
          name: body.name,
          trigger: body.trigger as any,
          triggerConfig: body.triggerConfig,
          action: body.action as any,
          actionConfig: body.actionConfig,
          isActive: body.isActive,
          businessId,
        },
      });

      return reply.code(201).send(rule);
    },
  });

  // ── GET /automation/rules ──
  app.get('/automation/rules', {
    schema: {
      tags: ['Automation'],
      summary: 'List automation rules',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          isActive: { type: 'string', enum: ['true', 'false'] },
          trigger: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
          offset: { type: 'integer', minimum: 0, default: 0 },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = ruleListQuerySchema.parse(request.query);

      const where: Record<string, unknown> = { businessId };
      if (query.isActive !== undefined) where.isActive = query.isActive === 'true';
      if (query.trigger) where.trigger = query.trigger;

      const [data, total] = await Promise.all([
        prisma.automationRule.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          take: query.limit,
          skip: query.offset,
        }),
        prisma.automationRule.count({ where }),
      ]);

      return reply.send({ data, total });
    },
  });

  // ── PUT /automation/rules/:id ──
  app.put('/automation/rules/:id', {
    schema: {
      tags: ['Automation'],
      summary: 'Update an automation rule',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };
      const body = updateRuleSchema.parse(request.body);

      const existing = await prisma.automationRule.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('AutomationRule', id);

      const data: Record<string, unknown> = {};
      if (body.name !== undefined) data.name = body.name;
      if (body.trigger !== undefined) data.trigger = body.trigger;
      if (body.triggerConfig !== undefined) data.triggerConfig = body.triggerConfig;
      if (body.action !== undefined) data.action = body.action;
      if (body.actionConfig !== undefined) data.actionConfig = body.actionConfig;
      if (body.isActive !== undefined) data.isActive = body.isActive;

      const updated = await prisma.automationRule.update({
        where: { id },
        data,
      });

      return reply.send(updated);
    },
  });

  // ── DELETE /automation/rules/:id ──
  app.delete('/automation/rules/:id', {
    schema: {
      tags: ['Automation'],
      summary: 'Delete an automation rule',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };

      const existing = await prisma.automationRule.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('AutomationRule', id);

      await prisma.automationRule.delete({ where: { id } });

      return reply.send({ success: true });
    },
  });

  // ── GET /automation/rules/:id/history ──
  app.get('/automation/rules/:id/history', {
    schema: {
      tags: ['Automation'],
      summary: 'Get trigger history for an automation rule from audit log',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };

      const existing = await prisma.automationRule.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('AutomationRule', id);

      // Fetch audit logs related to this automation rule
      const logs = await prisma.auditLog.findMany({
        where: {
          businessId,
          entityType: 'AutomationRule',
          entityId: id,
        },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });

      return reply.send({
        data: logs,
        rule: {
          id: existing.id,
          name: existing.name,
          timesTriggered: existing.timesTriggered,
          lastTriggeredAt: existing.lastTriggeredAt,
        },
      });
    },
  });

  // ── POST /automation/rules/:id/test ──
  app.post('/automation/rules/:id/test', {
    schema: {
      tags: ['Automation'],
      summary: 'Test-evaluate a rule against current data (dry run)',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };

      const result = await automationService.executeRule(businessId, id, /* dryRun */ true);

      return reply.send({ dryRun: true, ...result });
    },
  });
}
