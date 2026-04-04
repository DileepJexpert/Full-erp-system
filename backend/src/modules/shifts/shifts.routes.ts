import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';

const createShiftSchema = z.object({
  userId: z.string(),
  locationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  shiftStart: z.string().regex(/^\d{2}:\d{2}$/),
  shiftEnd: z.string().regex(/^\d{2}:\d{2}$/),
});

const shiftQuerySchema = z.object({
  weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  locationId: z.string().optional(),
  userId: z.string().optional(),
});

const updateShiftSchema = z.object({
  shiftStart: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  shiftEnd: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  userId: z.string().optional(),
  locationId: z.string().optional(),
});

export async function shiftRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /shifts/schedule ──
  app.post('/shifts/schedule', {
    schema: {
      tags: ['Shifts'],
      summary: 'Create a shift schedule entry',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          userId: { type: 'string' },
          locationId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          shiftStart: { type: 'string', pattern: '^\\d{2}:\\d{2}$' },
          shiftEnd: { type: 'string', pattern: '^\\d{2}:\\d{2}$' },
        },
        required: ['userId', 'locationId', 'date', 'shiftStart', 'shiftEnd'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const body = createShiftSchema.parse(request.body);

      const shift = await prisma.shiftSchedule.create({
        data: {
          userId: body.userId,
          locationId: body.locationId,
          date: new Date(body.date),
          shiftStart: body.shiftStart,
          shiftEnd: body.shiftEnd,
          businessId,
        },
      });

      return reply.code(201).send(shift);
    },
  });

  // ── GET /shifts/schedule ──
  app.get('/shifts/schedule', {
    schema: {
      tags: ['Shifts'],
      summary: 'Get shift schedule for a week',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          weekStart: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          locationId: { type: 'string' },
          userId: { type: 'string' },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId, userId, role } = request.tenant;
      const query = shiftQuerySchema.parse(request.query);

      const weekStart = query.weekStart ? new Date(query.weekStart) : getMonday(new Date());
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 6);

      const where: Record<string, unknown> = {
        businessId,
        date: { gte: weekStart, lte: weekEnd },
      };

      if (query.locationId) where.locationId = query.locationId;

      // Staff sees only own shifts
      if (role === 'STAFF') {
        where.userId = userId;
      } else if (query.userId) {
        where.userId = query.userId;
      }

      const shifts = await prisma.shiftSchedule.findMany({
        where,
        orderBy: { date: 'asc' },
      });

      return reply.send({ data: shifts });
    },
  });

  // ── PUT /shifts/schedule/:id ──
  app.put('/shifts/schedule/:id', {
    schema: {
      tags: ['Shifts'],
      summary: 'Update a shift schedule entry',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
      body: {
        type: 'object',
        properties: {
          shiftStart: { type: 'string', pattern: '^\\d{2}:\\d{2}$' },
          shiftEnd: { type: 'string', pattern: '^\\d{2}:\\d{2}$' },
          userId: { type: 'string' },
          locationId: { type: 'string' },
        },
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;
      const { id } = request.params as { id: string };
      const body = updateShiftSchema.parse(request.body);

      const existing = await prisma.shiftSchedule.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('ShiftSchedule', id);

      const updated = await prisma.shiftSchedule.update({
        where: { id },
        data: body,
      });

      return reply.send(updated);
    },
  });

  // ── DELETE /shifts/schedule/:id ──
  app.delete('/shifts/schedule/:id', {
    schema: {
      tags: ['Shifts'],
      summary: 'Delete a shift schedule entry',
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

      const existing = await prisma.shiftSchedule.findFirst({
        where: { id, businessId },
      });
      if (!existing) throw new NotFoundError('ShiftSchedule', id);

      await prisma.shiftSchedule.delete({ where: { id } });

      return reply.send({ success: true });
    },
  });
}

/** Return the Monday of the given week. */
function getMonday(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  d.setDate(diff);
  d.setHours(0, 0, 0, 0);
  return d;
}
