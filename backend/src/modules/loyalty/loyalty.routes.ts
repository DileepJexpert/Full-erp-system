import type { FastifyInstance } from 'fastify';
import { customerQuerySchema, createCustomerSchema } from './loyalty.schema.js';
import * as loyaltyService from './loyalty.service.js';
import { authenticate } from '../../middleware/authenticate.js';

export async function loyaltyRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.get('/customers', {
    schema: { tags: ['Loyalty'], summary: 'List customers', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const query = customerQuerySchema.parse(request.query);
      const result = await loyaltyService.getCustomers(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/customers/:id', {
    schema: { tags: ['Loyalty'], summary: 'Get customer by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await loyaltyService.getCustomerById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.post('/customers', {
    schema: { tags: ['Loyalty'], summary: 'Create or update customer', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const body = createCustomerSchema.parse(request.body);
      const result = await loyaltyService.createCustomer(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });

  app.get('/customers/lookup/:phone', {
    schema: { tags: ['Loyalty'], summary: 'Lookup customer by phone', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { phone } = request.params as { phone: string };
      const result = await loyaltyService.getCustomerByPhone(request.tenant.businessId, phone);
      return reply.send(result);
    },
  });
}
