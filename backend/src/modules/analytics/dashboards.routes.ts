import type { FastifyInstance } from 'fastify';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';

export async function dashboardRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // ─── POST /dashboards ───────────────────────────────────────
  app.post('/dashboards', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Create a custom dashboard',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          name: { type: 'string', minLength: 1 },
          layout: { type: 'object' },
        },
        required: ['name', 'layout'],
      },
    },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const { name, layout } = request.body as { name: string; layout: object };
      const dashboard = await prisma.customDashboard.create({
        data: {
          name,
          layout,
          businessId: request.tenant.businessId,
          userId: request.tenant.userId,
        },
      });
      return reply.code(201).send(dashboard);
    },
  });

  // ─── GET /dashboards ────────────────────────────────────────
  app.get('/dashboards', {
    schema: {
      tags: ['Dashboards'],
      summary: 'List user dashboards',
      security: [{ bearerAuth: [] }],
    },
    handler: async (request, reply) => {
      const dashboards = await prisma.customDashboard.findMany({
        where: {
          businessId: request.tenant.businessId,
          userId: request.tenant.userId,
        },
        orderBy: { createdAt: 'desc' },
        include: { widgets: true },
      });
      return reply.send(dashboards);
    },
  });

  // ─── GET /dashboards/:id ────────────────────────────────────
  app.get('/dashboards/:id', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Get dashboard with widgets',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const dashboard = await prisma.customDashboard.findFirst({
        where: {
          id,
          businessId: request.tenant.businessId,
          userId: request.tenant.userId,
        },
        include: { widgets: true },
      });
      if (!dashboard) throw new NotFoundError('Dashboard', id);
      return reply.send(dashboard);
    },
  });

  // ─── PUT /dashboards/:id ───────────────────────────────────
  app.put('/dashboards/:id', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Update dashboard',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
      body: {
        type: 'object',
        properties: {
          name: { type: 'string', minLength: 1 },
          layout: { type: 'object' },
          isDefault: { type: 'boolean' },
        },
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = request.body as { name?: string; layout?: object; isDefault?: boolean };
      const existing = await prisma.customDashboard.findFirst({
        where: { id, businessId: request.tenant.businessId, userId: request.tenant.userId },
      });
      if (!existing) throw new NotFoundError('Dashboard', id);

      const dashboard = await prisma.customDashboard.update({
        where: { id },
        data: {
          ...(body.name !== undefined && { name: body.name }),
          ...(body.layout !== undefined && { layout: body.layout }),
          ...(body.isDefault !== undefined && { isDefault: body.isDefault }),
        },
        include: { widgets: true },
      });
      return reply.send(dashboard);
    },
  });

  // ─── DELETE /dashboards/:id ─────────────────────────────────
  app.delete('/dashboards/:id', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Delete dashboard',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const existing = await prisma.customDashboard.findFirst({
        where: { id, businessId: request.tenant.businessId, userId: request.tenant.userId },
      });
      if (!existing) throw new NotFoundError('Dashboard', id);
      await prisma.customDashboard.delete({ where: { id } });
      return reply.send({ success: true });
    },
  });

  // ─── POST /dashboards/:id/widgets ──────────────────────────
  app.post('/dashboards/:id/widgets', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Add widget to dashboard',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
      body: {
        type: 'object',
        properties: {
          type: { type: 'string', minLength: 1 },
          title: { type: 'string', minLength: 1 },
          config: { type: 'object' },
          position: { type: 'object' },
        },
        required: ['type', 'title', 'config', 'position'],
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = request.body as { type: string; title: string; config: object; position: object };

      const dashboard = await prisma.customDashboard.findFirst({
        where: { id, businessId: request.tenant.businessId, userId: request.tenant.userId },
      });
      if (!dashboard) throw new NotFoundError('Dashboard', id);

      const widget = await prisma.dashboardWidget.create({
        data: {
          type: body.type,
          title: body.title,
          config: body.config,
          position: body.position,
          dashboardId: id,
        },
      });
      return reply.code(201).send(widget);
    },
  });

  // ─── PUT /dashboards/:id/widgets/:widgetId ─────────────────
  app.put('/dashboards/:id/widgets/:widgetId', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Update widget',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          widgetId: { type: 'string' },
        },
        required: ['id', 'widgetId'],
      },
      body: {
        type: 'object',
        properties: {
          type: { type: 'string' },
          title: { type: 'string' },
          config: { type: 'object' },
          position: { type: 'object' },
        },
      },
    },
    handler: async (request, reply) => {
      const { id, widgetId } = request.params as { id: string; widgetId: string };
      const body = request.body as { type?: string; title?: string; config?: object; position?: object };

      const dashboard = await prisma.customDashboard.findFirst({
        where: { id, businessId: request.tenant.businessId, userId: request.tenant.userId },
      });
      if (!dashboard) throw new NotFoundError('Dashboard', id);

      const widget = await prisma.dashboardWidget.findFirst({
        where: { id: widgetId, dashboardId: id },
      });
      if (!widget) throw new NotFoundError('Widget', widgetId);

      const updated = await prisma.dashboardWidget.update({
        where: { id: widgetId },
        data: {
          ...(body.type !== undefined && { type: body.type }),
          ...(body.title !== undefined && { title: body.title }),
          ...(body.config !== undefined && { config: body.config }),
          ...(body.position !== undefined && { position: body.position }),
        },
      });
      return reply.send(updated);
    },
  });

  // ─── DELETE /dashboards/:id/widgets/:widgetId ───────────────
  app.delete('/dashboards/:id/widgets/:widgetId', {
    schema: {
      tags: ['Dashboards'],
      summary: 'Remove widget from dashboard',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          widgetId: { type: 'string' },
        },
        required: ['id', 'widgetId'],
      },
    },
    handler: async (request, reply) => {
      const { id, widgetId } = request.params as { id: string; widgetId: string };

      const dashboard = await prisma.customDashboard.findFirst({
        where: { id, businessId: request.tenant.businessId, userId: request.tenant.userId },
      });
      if (!dashboard) throw new NotFoundError('Dashboard', id);

      const widget = await prisma.dashboardWidget.findFirst({
        where: { id: widgetId, dashboardId: id },
      });
      if (!widget) throw new NotFoundError('Widget', widgetId);

      await prisma.dashboardWidget.delete({ where: { id: widgetId } });
      return reply.send({ success: true });
    },
  });
}
