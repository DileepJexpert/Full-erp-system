import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as deliveryService from './delivery.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const recordProofSchema = z.object({
  photoUrl: z.string().optional(),
  signatureUrl: z.string().optional(),
  gpsLatitude: z.number().optional(),
  gpsLongitude: z.number().optional(),
  receiverName: z.string().optional(),
  notes: z.string().optional(),
  dispatchId: z.string().optional(),
  billId: z.string().optional(),
});

const proofQuerySchema = z.object({
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  deliveredById: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

export async function deliveryRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // POST /delivery/proof - record proof
  app.post('/delivery/proof', {
    schema: { tags: ['Delivery'], summary: 'Record delivery proof', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = recordProofSchema.parse(request.body);
      const result = await deliveryService.recordDeliveryProof(request.tenant.businessId, {
        ...body,
        deliveredById: request.tenant.userId,
      });
      return reply.code(201).send(result);
    },
  });

  // GET /delivery/proof - list
  app.get('/delivery/proof', {
    schema: { tags: ['Delivery'], summary: 'List delivery proofs', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const query = proofQuerySchema.parse(request.query);
      const result = await deliveryService.getDeliveryProof(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  // GET /delivery/proof/dispatch/:dispatchId - by dispatch (must be before :id to avoid conflict)
  app.get('/delivery/proof/dispatch/:dispatchId', {
    schema: { tags: ['Delivery'], summary: 'Get delivery proof by dispatch', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { dispatchId } = request.params as { dispatchId: string };
      const result = await deliveryService.getDeliveryProofByDispatch(request.tenant.businessId, dispatchId);
      return reply.send(result);
    },
  });

  // GET /delivery/proof/:id - detail
  app.get('/delivery/proof/:id', {
    schema: { tags: ['Delivery'], summary: 'Get delivery proof detail', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await deliveryService.getDeliveryProofById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });
}
