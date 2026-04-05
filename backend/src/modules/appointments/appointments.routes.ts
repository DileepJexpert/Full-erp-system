import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as appointmentService from './appointments.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const createAppointmentSchema = z.object({
  date: z.string(),
  startTime: z.string().regex(/^\d{2}:\d{2}$/),
  endTime: z.string().regex(/^\d{2}:\d{2}$/),
  serviceName: z.string().min(1),
  amount: z.number().optional(),
  notes: z.string().optional(),
  locationId: z.string().min(1),
  customerId: z.string().optional(),
  customerName: z.string().min(1),
  customerPhone: z.string().min(1),
  assignedToId: z.string().optional(),
});

const updateAppointmentSchema = z.object({
  date: z.string().optional(),
  startTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  endTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  serviceName: z.string().min(1).optional(),
  amount: z.number().optional(),
  notes: z.string().nullable().optional(),
  locationId: z.string().optional(),
  customerName: z.string().min(1).optional(),
  customerPhone: z.string().min(1).optional(),
  assignedToId: z.string().nullable().optional(),
});

const statusSchema = z.object({
  status: z.enum([
    'APPT_BOOKED',
    'APPT_CONFIRMED',
    'APPT_IN_PROGRESS',
    'APPT_COMPLETED',
    'APPT_CANCELLED',
    'APPT_NO_SHOW',
  ]),
});

const querySchema = z.object({
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  locationId: z.string().optional(),
  status: z.string().optional(),
  assignedToId: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

const slotsQuerySchema = z.object({
  locationId: z.string(),
  date: z.string(),
  duration: z.coerce.number().int().positive(),
});

export async function appointmentRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // POST /appointments - create
  app.post('/appointments', {
    schema: { tags: ['Appointments'], summary: 'Create an appointment', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = createAppointmentSchema.parse(request.body);
      const result = await appointmentService.createAppointment(request.tenant.businessId, {
        ...body,
        createdById: request.tenant.userId,
      });
      return reply.code(201).send(result);
    },
  });

  // GET /appointments - list with filters
  app.get('/appointments', {
    schema: { tags: ['Appointments'], summary: 'List appointments', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const query = querySchema.parse(request.query);
      const result = await appointmentService.getAppointments(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  // GET /appointments/today/:locationId - today's appointments
  app.get('/appointments/today/:locationId', {
    schema: { tags: ['Appointments'], summary: "Today's appointments for a location", security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { locationId } = request.params as { locationId: string };
      const result = await appointmentService.getTodayAppointments(request.tenant.businessId, locationId);
      return reply.send(result);
    },
  });

  // GET /appointments/slots - available slots
  app.get('/appointments/slots', {
    schema: { tags: ['Appointments'], summary: 'Get available appointment slots', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const query = slotsQuerySchema.parse(request.query);
      const result = await appointmentService.getAvailableSlots(
        request.tenant.businessId,
        query.locationId,
        query.date,
        query.duration,
      );
      return reply.send(result);
    },
  });

  // GET /appointments/:id - detail
  app.get('/appointments/:id', {
    schema: { tags: ['Appointments'], summary: 'Get appointment detail', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await appointmentService.getAppointment(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  // PUT /appointments/:id - update
  app.put('/appointments/:id', {
    schema: { tags: ['Appointments'], summary: 'Update appointment', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = updateAppointmentSchema.parse(request.body);
      const result = await appointmentService.updateAppointment(request.tenant.businessId, id, body as any);
      return reply.send(result);
    },
  });

  // PUT /appointments/:id/status - change status
  app.put('/appointments/:id/status', {
    schema: { tags: ['Appointments'], summary: 'Update appointment status', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const { status } = statusSchema.parse(request.body);
      const result = await appointmentService.updateStatus(request.tenant.businessId, id, status);
      return reply.send(result);
    },
  });

  // PUT /appointments/:id/no-show - mark no-show
  app.put('/appointments/:id/no-show', {
    schema: { tags: ['Appointments'], summary: 'Mark appointment as no-show', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await appointmentService.markNoShow(request.tenant.businessId, id);
      return reply.send(result);
    },
  });
}
