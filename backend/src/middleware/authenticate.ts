import type { FastifyRequest, FastifyReply } from 'fastify';
import { verifyToken } from '../plugins/auth.js';
import { UnauthorizedError } from '../utils/errors.js';

export async function authenticate(
  request: FastifyRequest,
  _reply: FastifyReply,
): Promise<void> {
  const authHeader = request.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing or invalid Authorization header');
  }

  const token = authHeader.slice(7);
  try {
    const payload = verifyToken(token);
    request.tenant = {
      userId: payload.userId,
      businessId: payload.businessId,
      role: payload.role,
      phone: payload.phone,
    };
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
}
