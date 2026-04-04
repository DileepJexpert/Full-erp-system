import type { FastifyInstance } from 'fastify';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';
import { generateDailySummary, generateWeeklyPL, generateMonthlyReview, generateGSTSummary } from './report-generator.service.js';

const VALID_REPORT_TYPES = ['daily_summary', 'weekly_pl', 'monthly_review', 'gst_summary'];
const VALID_FREQUENCIES = ['daily', 'weekly', 'monthly'];
const VALID_CHANNELS = ['email', 'whatsapp', 'both'];

export async function scheduledReportRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // ─── POST /scheduled-reports ────────────────────────────────
  app.post('/scheduled-reports', {
    schema: {
      tags: ['Scheduled Reports'],
      summary: 'Create a scheduled report config',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          name: { type: 'string', minLength: 1 },
          reportType: { type: 'string', enum: VALID_REPORT_TYPES },
          frequency: { type: 'string', enum: VALID_FREQUENCIES },
          channel: { type: 'string', enum: VALID_CHANNELS },
          recipients: {
            type: 'array',
            items: { type: 'string' },
            minItems: 1,
          },
          config: { type: 'object' },
        },
        required: ['name', 'reportType', 'frequency', 'channel', 'recipients'],
      },
    },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const body = request.body as {
        name: string;
        reportType: string;
        frequency: string;
        channel: string;
        recipients: string[];
        config?: object;
      };

      const report = await prisma.scheduledReport.create({
        data: {
          name: body.name,
          reportType: body.reportType,
          frequency: body.frequency,
          channel: body.channel,
          recipients: body.recipients,
          config: body.config ?? {},
          businessId: request.tenant.businessId,
        },
      });
      return reply.code(201).send(report);
    },
  });

  // ─── GET /scheduled-reports ─────────────────────────────────
  app.get('/scheduled-reports', {
    schema: {
      tags: ['Scheduled Reports'],
      summary: 'List scheduled report configs',
      security: [{ bearerAuth: [] }],
    },
    handler: async (request, reply) => {
      const reports = await prisma.scheduledReport.findMany({
        where: { businessId: request.tenant.businessId },
        orderBy: { createdAt: 'desc' },
      });
      return reply.send(reports);
    },
  });

  // ─── PUT /scheduled-reports/:id ─────────────────────────────
  app.put('/scheduled-reports/:id', {
    schema: {
      tags: ['Scheduled Reports'],
      summary: 'Update scheduled report config',
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
          reportType: { type: 'string', enum: VALID_REPORT_TYPES },
          frequency: { type: 'string', enum: VALID_FREQUENCIES },
          channel: { type: 'string', enum: VALID_CHANNELS },
          recipients: { type: 'array', items: { type: 'string' } },
          config: { type: 'object' },
          isActive: { type: 'boolean' },
        },
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = request.body as Record<string, unknown>;

      const existing = await prisma.scheduledReport.findFirst({
        where: { id, businessId: request.tenant.businessId },
      });
      if (!existing) throw new NotFoundError('ScheduledReport', id);

      const updated = await prisma.scheduledReport.update({
        where: { id },
        data: {
          ...(body.name !== undefined && { name: body.name as string }),
          ...(body.reportType !== undefined && { reportType: body.reportType as string }),
          ...(body.frequency !== undefined && { frequency: body.frequency as string }),
          ...(body.channel !== undefined && { channel: body.channel as string }),
          ...(body.recipients !== undefined && { recipients: body.recipients }),
          ...(body.config !== undefined && { config: body.config }),
          ...(body.isActive !== undefined && { isActive: body.isActive as boolean }),
        },
      });
      return reply.send(updated);
    },
  });

  // ─── DELETE /scheduled-reports/:id ──────────────────────────
  app.delete('/scheduled-reports/:id', {
    schema: {
      tags: ['Scheduled Reports'],
      summary: 'Delete scheduled report config',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const existing = await prisma.scheduledReport.findFirst({
        where: { id, businessId: request.tenant.businessId },
      });
      if (!existing) throw new NotFoundError('ScheduledReport', id);

      await prisma.scheduledReport.delete({ where: { id } });
      return reply.send({ success: true });
    },
  });

  // ─── POST /scheduled-reports/:id/send-now ───────────────────
  app.post('/scheduled-reports/:id/send-now', {
    schema: {
      tags: ['Scheduled Reports'],
      summary: 'Manually trigger report generation and delivery',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const report = await prisma.scheduledReport.findFirst({
        where: { id, businessId: request.tenant.businessId },
      });
      if (!report) throw new NotFoundError('ScheduledReport', id);

      const businessId = request.tenant.businessId;
      const now = new Date();
      let data: unknown;

      switch (report.reportType) {
        case 'daily_summary':
          data = await generateDailySummary(businessId, now);
          break;
        case 'weekly_pl': {
          const weekStart = new Date(now);
          weekStart.setDate(weekStart.getDate() - weekStart.getDay());
          data = await generateWeeklyPL(businessId, weekStart);
          break;
        }
        case 'monthly_review': {
          const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
          data = await generateMonthlyReview(businessId, month);
          break;
        }
        case 'gst_summary': {
          const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
          data = await generateGSTSummary(businessId, month);
          break;
        }
        default:
          throw new BadRequestError(`Unknown report type: ${report.reportType}`);
      }

      // Update lastSentAt
      await prisma.scheduledReport.update({
        where: { id },
        data: { lastSentAt: now },
      });

      // TODO: Actually deliver via email/whatsapp based on report.channel + report.recipients
      console.log(`[REPORT] Manually triggered report "${report.name}" for business ${businessId}, channel: ${report.channel}`);

      return reply.send({
        success: true,
        reportType: report.reportType,
        generatedAt: now.toISOString(),
        data,
      });
    },
  });
}
