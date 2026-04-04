import type { FastifyInstance } from 'fastify';
import { computeSalarySchema, salaryQuerySchema } from './salary.schema.js';
import * as salaryService from './salary.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function salaryRoutes(app: FastifyInstance): Promise<void> {
  app.post('/salary/compute', {
    schema: {
      tags: ['Salary'],
      summary: 'Compute monthly salary for an operator',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          operatorId: { type: 'string' },
          month: { type: 'string', pattern: '^\\d{4}-\\d{2}$' },
          bonus: { type: 'number', minimum: 0, default: 0 },
          adjustments: { type: 'number', default: 0 },
          adjustmentNotes: { type: 'string' },
        },
        required: ['operatorId', 'month'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = computeSalarySchema.parse(request.body);
      const result = await salaryService.computeSalary(
        request.tenant.businessId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/salary', {
    schema: {
      tags: ['Salary'],
      summary: 'List salary records with pagination and filtering',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          month: { type: 'string' },
          status: { type: 'string', enum: ['DRAFT', 'FINALIZED', 'PAID'] },
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const query = salaryQuerySchema.parse(request.query);
      const result = await salaryService.getSalaryRecords(
        request.tenant.businessId,
        query,
      );
      return reply.send(result);
    },
  });

  app.post('/salary/:id/finalize', {
    schema: {
      tags: ['Salary'],
      summary: 'Finalize a salary record',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await salaryService.finalizeSalary(
        request.tenant.businessId,
        id,
      );
      return reply.send(result);
    },
  });

  app.post('/salary/:id/pay', {
    schema: {
      tags: ['Salary'],
      summary: 'Mark a salary record as paid',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await salaryService.markPaid(
        request.tenant.businessId,
        id,
      );
      return reply.send(result);
    },
  });

  app.post('/salary/advance', {
    schema: {
      tags: ['Salary'],
      summary: 'Record a salary advance for an operator',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          operatorId: { type: 'string' },
          amount: { type: 'number', minimum: 0 },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
          notes: { type: 'string' },
        },
        required: ['operatorId', 'amount', 'date'],
      },
    },
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { operatorId, amount, date, notes } = request.body as {
        operatorId: string;
        amount: number;
        date: string;
        notes?: string;
      };
      const result = await salaryService.addAdvance(
        request.tenant.businessId,
        operatorId,
        amount,
        date,
        notes,
      );
      return reply.code(201).send(result);
    },
  });
}
