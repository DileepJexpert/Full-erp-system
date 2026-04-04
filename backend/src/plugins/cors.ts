import type { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';

export async function registerCors(app: FastifyInstance): Promise<void> {
  await app.register(cors, {
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });
}
