import type { FastifyInstance } from 'fastify';
import jwt from 'jsonwebtoken';
import { getEnv } from '../config/env.js';
import type { TenantContext } from '../types/index.js';

export interface JwtPayload {
  userId: string;
  businessId: string;
  role: 'OWNER' | 'MANAGER' | 'STAFF';
  phone: string;
}

export function signToken(payload: JwtPayload): string {
  const env = getEnv();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRY } as any);
}

export function verifyToken(token: string): JwtPayload {
  const env = getEnv();
  return jwt.verify(token, env.JWT_SECRET) as JwtPayload;
}

export async function registerAuth(app: FastifyInstance): Promise<void> {
  app.decorateRequest('tenant', null);
}
