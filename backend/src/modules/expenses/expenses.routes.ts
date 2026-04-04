import type { FastifyInstance } from 'fastify';
import { createExpenseSchema, expenseQuerySchema } from './expenses.schema.js';
import * as expensesService from './expenses.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function expensesRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/expenses', {
    schema: { tags: ['Expenses'], summary: 'Create a new expense', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const body = createExpenseSchema.parse(request.body);
      const result = await expensesService.createExpense(
        request.tenant.businessId,
        request.tenant.userId,
        body,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/expenses', {
    schema: { tags: ['Expenses'], summary: 'List expenses with filtering', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const query = expenseQuerySchema.parse(request.query);
      const result = await expensesService.getExpenses(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/expenses/:id', {
    schema: { tags: ['Expenses'], summary: 'Get expense by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await expensesService.getExpenseById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.delete('/expenses/:id', {
    schema: { tags: ['Expenses'], summary: 'Delete expense', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await expensesService.deleteExpense(request.tenant.businessId, id);
      return reply.code(204).send();
    },
  });
}
