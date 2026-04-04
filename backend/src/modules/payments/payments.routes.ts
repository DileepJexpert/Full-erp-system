import type { FastifyInstance } from 'fastify';
import { createQrSchema, createOrderSchema } from './payments.schema.js';
import * as paymentsService from './payments.service.js';
import { authenticate } from '../../middleware/authenticate.js';

export async function paymentRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/payments/qr', {
    schema: { tags: ['Payments'], summary: 'Generate QR code for payment', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const body = createQrSchema.parse(request.body);
      const result = await paymentsService.createQrCode(request.tenant.businessId, body);
      return reply.send(result);
    },
  });

  app.post('/payments/order', {
    schema: { tags: ['Payments'], summary: 'Create Razorpay order', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const body = createOrderSchema.parse(request.body);
      const result = await paymentsService.createOrder(request.tenant.businessId, body);
      return reply.send(result);
    },
  });
}
