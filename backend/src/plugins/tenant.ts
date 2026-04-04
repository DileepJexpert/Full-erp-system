import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { asyncLocalStorage } from '../lib/prisma.js';

export async function registerTenant(app: FastifyInstance): Promise<void> {
  // This plugin wraps route handlers in AsyncLocalStorage context
  // so that Prisma middleware can access businessId automatically
  app.addHook('preHandler', async (request: FastifyRequest, _reply: FastifyReply) => {
    if (request.tenant?.businessId) {
      // Set the async local storage for the duration of this request
      const store = { businessId: request.tenant.businessId };
      asyncLocalStorage.enterWith(store);
    }
  });
}
