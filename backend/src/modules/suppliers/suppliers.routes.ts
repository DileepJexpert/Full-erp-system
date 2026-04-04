import type { FastifyInstance } from 'fastify';
import { createSupplierSchema, updateSupplierSchema } from './suppliers.schema.js';
import * as suppliersService from './suppliers.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function suppliersRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/suppliers', {
    schema: { tags: ['Suppliers'], summary: 'Create a new supplier', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = createSupplierSchema.parse(request.body);
      const result = await suppliersService.createSupplier(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });

  app.get('/suppliers', {
    schema: { tags: ['Suppliers'], summary: 'List all active suppliers', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const result = await suppliersService.getSuppliers(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/suppliers/:id', {
    schema: { tags: ['Suppliers'], summary: 'Get supplier by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await suppliersService.getSupplierById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/suppliers/:id', {
    schema: { tags: ['Suppliers'], summary: 'Update supplier', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = updateSupplierSchema.parse(request.body);
      const result = await suppliersService.updateSupplier(request.tenant.businessId, id, body);
      return reply.send(result);
    },
  });

  app.delete('/suppliers/:id', {
    schema: { tags: ['Suppliers'], summary: 'Soft-delete supplier', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await suppliersService.deleteSupplier(request.tenant.businessId, id);
      return reply.code(204).send();
    },
  });
}
