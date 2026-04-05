import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as estimatesService from './estimates.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const estimateItemSchema = z.object({
  description: z.string().min(1),
  quantity: z.number().positive(),
  unitPrice: z.number().positive(),
  itemId: z.string().optional(),
});

const createEstimateSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  validUntil: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  customerId: z.string().optional(),
  customerName: z.string().optional(),
  customerPhone: z.string().optional(),
  locationId: z.string().optional(),
  notes: z.string().optional(),
  termsAndConditions: z.string().optional(),
  items: z.array(estimateItemSchema).min(1),
});

const updateEstimateSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  validUntil: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  customerId: z.string().optional(),
  customerName: z.string().optional(),
  customerPhone: z.string().optional(),
  notes: z.string().optional(),
  termsAndConditions: z.string().optional(),
  items: z.array(estimateItemSchema).min(1).optional(),
});

const estimateFiltersSchema = z.object({
  status: z.enum([
    'ESTIMATE_DRAFT', 'ESTIMATE_SENT', 'ESTIMATE_ACCEPTED',
    'ESTIMATE_REJECTED', 'ESTIMATE_CONVERTED', 'ESTIMATE_EXPIRED',
  ]).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

const convertSchema = z.object({
  locationId: z.string().min(1),
});

export async function estimatesRoutes(app: FastifyInstance): Promise<void> {
  app.post('/estimates', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = createEstimateSchema.parse(request.body);
      const result = await estimatesService.createEstimate(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/estimates', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const filters = estimateFiltersSchema.parse(request.query);
      const result = await estimatesService.getEstimates(request.tenant.businessId, filters);
      return reply.send(result);
    },
  });

  app.get('/estimates/:id', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await estimatesService.getEstimate(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/estimates/:id', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = updateEstimateSchema.parse(request.body);
      const result = await estimatesService.updateEstimate(request.tenant.businessId, id, body);
      return reply.send(result);
    },
  });

  app.post('/estimates/:id/send', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await estimatesService.sendEstimate(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.post('/estimates/:id/convert', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = convertSchema.parse(request.body);
      const result = await estimatesService.convertToInvoice(
        request.tenant.businessId,
        id,
        request.tenant.userId,
        body.locationId,
      );
      return reply.send(result);
    },
  });
}
