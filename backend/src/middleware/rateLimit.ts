import type { FastifyInstance } from 'fastify';
import rateLimit from '@fastify/rate-limit';

export async function registerRateLimit(app: FastifyInstance): Promise<void> {
  await app.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
    keyGenerator: (request) => {
      // Rate limit per tenant + IP
      const businessId = request.tenant?.businessId ?? 'anonymous';
      return `${businessId}:${request.ip}`;
    },
    errorResponseBuilder: (_request, context) => ({
      error: 'Too many requests',
      code: 'RATE_LIMITED',
      details: { retryAfter: context.after },
    }),
  });
}
