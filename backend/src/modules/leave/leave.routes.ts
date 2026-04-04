import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import * as leaveService from './leave.service.js';

const createLeaveSchema = z.object({
  type: z.enum(['CASUAL', 'SICK', 'EARNED', 'UNPAID']),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  reason: z.string().optional(),
});

const leaveListQuerySchema = z.object({
  status: z.string().optional(),
  userId: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export async function leaveRoutes(app: FastifyInstance): Promise<void> {
  // ── POST /leave/request ──
  app.post('/leave/request', {
    schema: {
      tags: ['Leave'],
      summary: 'Create a leave request',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: ['CASUAL', 'SICK', 'EARNED', 'UNPAID'] },
          startDate: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          endDate: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          reason: { type: 'string' },
        },
        required: ['type', 'startDate', 'endDate'],
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId, userId } = request.tenant;
      const body = createLeaveSchema.parse(request.body);
      const result = await leaveService.createLeaveRequest(businessId, userId, body);
      return reply.code(201).send(result);
    },
  });

  // ── GET /leave/requests ──
  app.get('/leave/requests', {
    schema: {
      tags: ['Leave'],
      summary: 'List leave requests',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          status: { type: 'string' },
          userId: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
          offset: { type: 'integer', minimum: 0, default: 0 },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId, userId, role } = request.tenant;
      const query = leaveListQuerySchema.parse(request.query);
      const result = await leaveService.listLeaveRequests(businessId, userId, role, query);
      return reply.send(result);
    },
  });

  // ── PUT /leave/requests/:id/approve ──
  app.put('/leave/requests/:id/approve', {
    schema: {
      tags: ['Leave'],
      summary: 'Approve a leave request',
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
      const result = await leaveService.approveLeave(businessId, id, userId);
      return reply.send(result);
    },
  });

  // ── PUT /leave/requests/:id/reject ──
  app.put('/leave/requests/:id/reject', {
    schema: {
      tags: ['Leave'],
      summary: 'Reject a leave request',
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
      const result = await leaveService.rejectLeave(businessId, id);
      return reply.send(result);
    },
  });

  // ── GET /leave/balance/:userId ──
  app.get('/leave/balance/:userId', {
    schema: {
      tags: ['Leave'],
      summary: 'Get leave balance for a user',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { userId: { type: 'string' } },
        required: ['userId'],
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { businessId, userId: callerId, role } = request.tenant;
      const { userId: targetUserId } = request.params as { userId: string };

      // Staff can only see own balance
      if (role === 'STAFF' && callerId !== targetUserId) {
        return reply.code(403).send({ error: 'Forbidden', message: 'Staff can only view own leave balance' });
      }

      const result = await leaveService.getLeaveBalance(businessId, targetUserId);
      return reply.send(result);
    },
  });
}
