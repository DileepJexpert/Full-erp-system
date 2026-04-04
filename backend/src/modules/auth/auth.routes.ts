import type { FastifyInstance } from 'fastify';
import { sendOtpSchema, verifyOtpSchema, registerBusinessSchema, addUserSchema } from './auth.schema.js';
import * as authService from './auth.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function authRoutes(app: FastifyInstance): Promise<void> {
  // Public routes
  app.post('/auth/send-otp', {
    schema: {
      tags: ['Auth'],
      summary: 'Send OTP to phone number',
      body: { type: 'object', properties: { phone: { type: 'string' } }, required: ['phone'] },
    },
    handler: async (request, reply) => {
      const body = sendOtpSchema.parse(request.body);
      const result = await authService.sendOtp(body.phone);
      return reply.send(result);
    },
  });

  app.post('/auth/verify-otp', {
    schema: {
      tags: ['Auth'],
      summary: 'Verify OTP and get JWT token',
      body: {
        type: 'object',
        properties: {
          phone: { type: 'string' },
          otp: { type: 'string' },
          businessId: { type: 'string' },
        },
        required: ['phone', 'otp'],
      },
    },
    handler: async (request, reply) => {
      const body = verifyOtpSchema.parse(request.body);
      const result = await authService.verifyOtpAndLogin(body.phone, body.otp, body.businessId);
      return reply.send(result);
    },
  });

  app.post('/auth/register', {
    schema: {
      tags: ['Auth'],
      summary: 'Register a new business with owner',
      body: {
        type: 'object',
        properties: {
          businessName: { type: 'string' },
          businessType: { type: 'string' },
          ownerName: { type: 'string' },
          phone: { type: 'string' },
          email: { type: 'string' },
        },
        required: ['businessName', 'businessType', 'ownerName', 'phone'],
      },
    },
    handler: async (request, reply) => {
      const body = registerBusinessSchema.parse(request.body);
      const result = await authService.registerBusiness(body);
      return reply.code(201).send(result);
    },
  });

  // Protected routes
  app.get('/auth/me', {
    schema: { tags: ['Auth'], summary: 'Get current user profile', security: [{ bearerAuth: [] }] },
    preHandler: [authenticate],
    handler: async (request, reply) => {
      const result = await authService.getMe(request.tenant.userId);
      return reply.send(result);
    },
  });

  app.get('/auth/users', {
    schema: { tags: ['Auth'], summary: 'List all users in business', security: [{ bearerAuth: [] }] },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await authService.getUsers(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.post('/auth/users', {
    schema: {
      tags: ['Auth'],
      summary: 'Add a new user to business',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          phone: { type: 'string' },
          role: { type: 'string', enum: ['MANAGER', 'STAFF'] },
          salaryType: { type: 'string', enum: ['FIXED', 'ATTENDANCE_BASED'] },
          baseSalary: { type: 'number' },
          aadhaar: { type: 'string' },
          language: { type: 'string' },
        },
        required: ['name', 'phone', 'role'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = addUserSchema.parse(request.body);
      const result = await authService.addUser(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });
}
