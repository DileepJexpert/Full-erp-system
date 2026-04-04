import type { FastifyRequest, FastifyReply } from 'fastify';
import { asyncLocalStorage } from '../lib/prisma.js';
import { UnauthorizedError } from '../utils/errors.js';

export async function tenantScope(
  request: FastifyRequest,
  _reply: FastifyReply,
): Promise<void> {
  const businessId = request.tenant?.businessId;
  if (!businessId) {
    throw new UnauthorizedError('Business context not found');
  }
  asyncLocalStorage.enterWith({ businessId });
}
