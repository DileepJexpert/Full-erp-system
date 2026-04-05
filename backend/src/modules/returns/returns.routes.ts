import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as returnsService from './returns.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const createReturnSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  reason: z.enum(['DAMAGED', 'EXPIRED', 'WRONG_ITEM', 'QUALITY_ISSUE', 'CUSTOMER_CHANGE', 'OTHER']),
  refundMode: z.enum(['CASH_REFUND', 'STORE_CREDIT', 'EXCHANGE', 'ORIGINAL_METHOD']),
  originalBillId: z.string().min(1),
  locationId: z.string().min(1),
  customerId: z.string().optional(),
  notes: z.string().optional(),
  items: z.array(z.object({
    itemId: z.string().min(1),
    quantity: z.number().int().positive(),
    unitPrice: z.number().positive(),
    isResaleable: z.boolean(),
  })).min(1),
});

const returnFiltersSchema = z.object({
  locationId: z.string().optional(),
  status: z.enum(['RETURN_PENDING', 'RETURN_APPROVED', 'RETURN_REJECTED', 'RETURN_COMPLETED']).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

const rejectSchema = z.object({
  reason: z.string().min(1, 'Rejection reason is required'),
});

export async function returnsRoutes(app: FastifyInstance): Promise<void> {
  app.post('/returns', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = createReturnSchema.parse(request.body);
      const result = await returnsService.createSalesReturn(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/returns', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const filters = returnFiltersSchema.parse(request.query);
      const result = await returnsService.getSalesReturns(request.tenant.businessId, filters);
      return reply.send(result);
    },
  });

  app.get('/returns/:id', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await returnsService.getSalesReturn(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/returns/:id/approve', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await returnsService.approveSalesReturn(
        request.tenant.businessId,
        id,
        request.tenant.userId,
      );
      return reply.send(result);
    },
  });

  app.put('/returns/:id/reject', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = rejectSchema.parse(request.body);
      const result = await returnsService.rejectSalesReturn(
        request.tenant.businessId,
        id,
        body.reason,
      );
      return reply.send(result);
    },
  });
}
