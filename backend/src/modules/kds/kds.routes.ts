import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as kdsService from './kds.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const createKdsOrderSchema = z.object({
  billId: z.string().min(1),
  locationId: z.string().min(1),
  priority: z.number().int().min(0).optional(),
  notes: z.string().optional(),
  items: z.array(z.object({
    itemName: z.string().min(1),
    quantity: z.number().int().positive(),
    notes: z.string().optional(),
    itemId: z.string().optional(),
  })).min(1),
});

const updateStatusSchema = z.object({
  status: z.enum(['KDS_NEW', 'KDS_PREPARING', 'KDS_READY', 'KDS_SERVED']),
});

const statsQuerySchema = z.object({
  date: z.string().optional(),
});

export async function kdsRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // POST /kds/orders - create from bill
  app.post('/kds/orders', {
    schema: { tags: ['KDS'], summary: 'Create KDS order from bill', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = createKdsOrderSchema.parse(request.body);
      const result = await kdsService.createKdsOrder(
        request.tenant.businessId,
        body.billId,
        body.locationId,
        body.items,
        body.priority,
        body.notes,
      );
      return reply.code(201).send(result);
    },
  });

  // GET /kds/orders/active/:locationId - active orders for kitchen display
  app.get('/kds/orders/active/:locationId', {
    schema: { tags: ['KDS'], summary: 'Get active KDS orders for location', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { locationId } = request.params as { locationId: string };
      const result = await kdsService.getActiveOrders(request.tenant.businessId, locationId);
      return reply.send(result);
    },
  });

  // PUT /kds/orders/:id/status - update status
  app.put('/kds/orders/:id/status', {
    schema: { tags: ['KDS'], summary: 'Update KDS order status', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const { status } = updateStatusSchema.parse(request.body);
      const result = await kdsService.updateOrderStatus(request.tenant.businessId, id, status);
      return reply.send(result);
    },
  });

  // GET /kds/orders/bill/:billId - orders for a bill
  app.get('/kds/orders/bill/:billId', {
    schema: { tags: ['KDS'], summary: 'Get KDS orders for a bill', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { billId } = request.params as { billId: string };
      const result = await kdsService.getOrdersByBill(request.tenant.businessId, billId);
      return reply.send(result);
    },
  });

  // GET /kds/stats/:locationId - stats for location
  app.get('/kds/stats/:locationId', {
    schema: { tags: ['KDS'], summary: 'Get KDS stats for location', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { locationId } = request.params as { locationId: string };
      const query = statsQuerySchema.parse(request.query);
      const result = await kdsService.getKdsStats(request.tenant.businessId, locationId, query.date);
      return reply.send(result);
    },
  });
}
