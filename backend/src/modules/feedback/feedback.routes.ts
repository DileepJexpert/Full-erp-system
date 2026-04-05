import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../../utils/errors.js';
import {
  authenticateKiosk,
  submitFeedback,
  getFeedbackSummary,
  getNpsBreakdown,
  listFeedback,
  verifyKioskToken,
} from './feedback.service.js';

// ─── Validation Schemas ─────────────────────────────────────

const kioskAuthSchema = z.object({
  deviceId: z.string().min(1),
  deviceName: z.string().min(1),
  locationPin: z.string().length(4),
  businessId: z.string().min(1),
});

const submitFeedbackSchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().optional(),
  tags: z.array(z.string()).optional(),
  billId: z.string().optional(),
  operatorId: z.string().optional(),
  batteryLevel: z.number().int().min(0).max(100).optional(),
});

const summaryQuerySchema = z.object({
  locationId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

const listQuerySchema = z.object({
  locationId: z.string().optional(),
  rating: z.coerce.number().int().min(1).max(5).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const npsQuerySchema = z.object({
  locationId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

const kioskSettingsSchema = z.object({
  locationId: z.string().min(1),
  feedbackKioskEnabled: z.boolean().optional(),
  feedbackDisplayMode: z.enum(['SIMPLE', 'WITH_COMMENT', 'WITH_TAGS']).optional(),
  feedbackAutoResetSec: z.number().int().min(3).max(60).optional(),
  feedbackShowBilingual: z.boolean().optional(),
  feedbackNegativeTags: z.array(z.string()).optional(),
  feedbackPositiveTags: z.array(z.string()).optional(),
});

// ─── Rate Limit Tracker (in-memory, per device) ─────────────

const deviceLastSubmit = new Map<string, number>();

// ─── Routes ─────────────────────────────────────────────────

export async function feedbackKioskRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /feedback/kiosk-auth (Public) ──
  app.post('/feedback/kiosk-auth', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'Authenticate kiosk device and get config',
    },
    handler: async (request, reply) => {
      const body = kioskAuthSchema.parse(request.body);
      const result = await authenticateKiosk(body);
      return reply.send(result);
    },
  });

  // ── POST /feedback/submit (Kiosk token auth) ──
  app.post('/feedback/submit', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'Submit feedback from kiosk device',
    },
    handler: async (request, reply) => {
      // Parse kiosk token from Authorization header
      const authHeader = request.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        throw new UnauthorizedError('Missing or invalid Authorization header');
      }

      const token = authHeader.slice(7);
      const kioskPayload = verifyKioskToken(token);

      // Rate limit: 1 submission per 10 seconds per device
      const now = Date.now();
      const lastSubmit = deviceLastSubmit.get(kioskPayload.deviceId);
      if (lastSubmit && now - lastSubmit < 10_000) {
        return reply.code(429).send({
          error: 'Too many requests',
          code: 'RATE_LIMITED',
          details: { retryAfter: '10s' },
        });
      }
      deviceLastSubmit.set(kioskPayload.deviceId, now);

      const body = submitFeedbackSchema.parse(request.body);

      const feedback = await submitFeedback({
        rating: body.rating,
        comment: body.comment,
        tags: body.tags,
        locationId: kioskPayload.locationId,
        businessId: kioskPayload.businessId,
        billId: body.billId,
        operatorId: body.operatorId,
        deviceId: kioskPayload.deviceId,
        channel: 'kiosk_display',
      });

      // Update KioskDevice lastSeenAt + batteryLevel
      await prisma.kioskDevice.updateMany({
        where: {
          deviceId: kioskPayload.deviceId,
          businessId: kioskPayload.businessId,
        },
        data: {
          lastSeenAt: new Date(),
          ...(body.batteryLevel !== undefined ? { batteryLevel: body.batteryLevel } : {}),
        },
      });

      return reply.code(201).send(feedback);
    },
  });

  // ── GET /feedback/summary (Manager+) ──
  app.get('/feedback/summary', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'Get feedback summary for business/location',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = summaryQuerySchema.parse(request.query);

      const result = await getFeedbackSummary(
        businessId,
        query.locationId,
        query.startDate ? new Date(query.startDate) : undefined,
        query.endDate ? new Date(query.endDate) : undefined,
      );

      return reply.send(result);
    },
  });

  // ── GET /feedback/list (Manager+) ──
  app.get('/feedback/list', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'List feedback with pagination',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = listQuerySchema.parse(request.query);

      const result = await listFeedback(businessId, query);

      return reply.send(result);
    },
  });

  // ── GET /feedback/nps (Owner) ──
  app.get('/feedback/nps', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'Get NPS breakdown',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const query = npsQuerySchema.parse(request.query);

      const result = await getNpsBreakdown(
        businessId,
        query.locationId,
        query.startDate ? new Date(query.startDate) : undefined,
        query.endDate ? new Date(query.endDate) : undefined,
      );

      return reply.send(result);
    },
  });

  // ── PUT /feedback/kiosk-settings (Owner) ──
  app.put('/feedback/kiosk-settings', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'Update kiosk display settings for a location',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const body = kioskSettingsSchema.parse(request.body);

      // Verify location belongs to this business
      const location = await prisma.location.findFirst({
        where: { id: body.locationId, businessId },
      });

      if (!location) {
        throw new NotFoundError('Location', body.locationId);
      }

      const { locationId, ...updateData } = body;

      const updated = await prisma.location.update({
        where: { id: locationId },
        data: updateData,
        select: {
          id: true,
          name: true,
          feedbackKioskEnabled: true,
          feedbackDisplayMode: true,
          feedbackAutoResetSec: true,
          feedbackShowBilingual: true,
          feedbackNegativeTags: true,
          feedbackPositiveTags: true,
        },
      });

      return reply.send(updated);
    },
  });

  // ── GET /feedback/realtime/:locationId (Manager+) ──
  app.get('/feedback/realtime/:locationId', {
    schema: {
      tags: ['Feedback Kiosk'],
      summary: 'Get last 20 feedback entries for a location (polling)',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { locationId } = request.params as { locationId: string };

      // Verify location belongs to this business
      const location = await prisma.location.findFirst({
        where: { id: locationId, businessId },
      });

      if (!location) {
        throw new NotFoundError('Location', locationId);
      }

      const feedback = await prisma.customerFeedback.findMany({
        where: { businessId, locationId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      });

      return reply.send({ data: feedback, pollIntervalMs: 10_000 });
    },
  });
}
