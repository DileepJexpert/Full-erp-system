import type { FastifyInstance } from 'fastify';
import { verifyWebhookSignature } from '../../lib/razorpay.js';
import { handlePaymentWebhook } from '../payments/payments.service.js';
import { BadRequestError } from '../../utils/errors.js';

export async function webhookRoutes(app: FastifyInstance): Promise<void> {
  // Razorpay webhook — no auth required, signature verified instead
  app.post('/webhooks/razorpay', {
    schema: { tags: ['Webhooks'], summary: 'Razorpay payment webhook' },
    config: { rawBody: true },
    handler: async (request, reply) => {
      const signature = request.headers['x-razorpay-signature'] as string;
      if (!signature) {
        throw new BadRequestError('Missing webhook signature');
      }

      const rawBody = JSON.stringify(request.body);
      const isValid = verifyWebhookSignature(rawBody, signature);
      if (!isValid) {
        throw new BadRequestError('Invalid webhook signature');
      }

      const body = request.body as { event: string; payload: any };
      await handlePaymentWebhook(null, body.event, body.payload);

      return reply.send({ status: 'ok' });
    },
  });
}
