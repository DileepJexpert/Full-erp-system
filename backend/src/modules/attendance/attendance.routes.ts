import type { FastifyInstance } from 'fastify';
import { checkInSchema, checkOutSchema, attendanceQuerySchema } from './attendance.schema.js';
import * as attendanceService from './attendance.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function attendanceRoutes(app: FastifyInstance): Promise<void> {
  app.post('/attendance/check-in', {
    schema: {
      tags: ['Attendance'],
      summary: 'Check in at a location',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          checkInLat: { type: 'number' },
          checkInLng: { type: 'number' },
          isSubstitute: { type: 'boolean', default: false },
        },
        required: ['locationId', 'date'],
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const body = checkInSchema.parse(request.body);
      const result = await attendanceService.checkIn(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.post('/attendance/check-out', {
    schema: {
      tags: ['Attendance'],
      summary: 'Check out from attendance',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          attendanceId: { type: 'string' },
        },
        required: ['attendanceId'],
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const body = checkOutSchema.parse(request.body);
      const result = await attendanceService.checkOut(
        request.tenant.businessId,
        body.attendanceId,
      );
      return reply.send(result);
    },
  });

  app.get('/attendance', {
    schema: {
      tags: ['Attendance'],
      summary: 'List attendance records with pagination and filtering',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          locationId: { type: 'string' },
          operatorId: { type: 'string' },
          startDate: { type: 'string' },
          endDate: { type: 'string' },
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
        },
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const query = attendanceQuerySchema.parse(request.query);
      const result = await attendanceService.getAttendance(
        request.tenant.businessId,
        query,
      );
      return reply.send(result);
    },
  });

  app.get('/attendance/:id', {
    schema: {
      tags: ['Attendance'],
      summary: 'Get a single attendance record by ID',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await attendanceService.getAttendanceById(
        request.tenant.businessId,
        id,
      );
      return reply.send(result);
    },
  });
}
