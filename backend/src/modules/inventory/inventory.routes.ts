import type { FastifyInstance } from 'fastify';
import { createItemSchema, updateItemSchema, itemQuerySchema } from './inventory.schema.js';
import * as inventoryService from './inventory.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

export async function inventoryRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.post('/inventory', {
    schema: { tags: ['Inventory'], summary: 'Create a new item', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = createItemSchema.parse(request.body);
      const result = await inventoryService.createItem(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });

  app.get('/inventory', {
    schema: { tags: ['Inventory'], summary: 'List items with filtering', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const query = itemQuerySchema.parse(request.query);
      const result = await inventoryService.getItems(request.tenant.businessId, query);
      return reply.send(result);
    },
  });

  app.get('/inventory/:id', {
    schema: { tags: ['Inventory'], summary: 'Get item by ID', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await inventoryService.getItemById(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/inventory/:id', {
    schema: { tags: ['Inventory'], summary: 'Update item', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = updateItemSchema.parse(request.body);
      const result = await inventoryService.updateItem(request.tenant.businessId, id, body);
      return reply.send(result);
    },
  });

  app.delete('/inventory/:id', {
    schema: { tags: ['Inventory'], summary: 'Soft-delete item', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await inventoryService.deleteItem(request.tenant.businessId, id);
      return reply.code(204).send();
    },
  });
}
