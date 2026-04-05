import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as recipesService from './recipes.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const ingredientSchema = z.object({
  ingredientItemId: z.string().min(1),
  quantity: z.number().positive(),
  unit: z.string().min(1),
  wastagePercent: z.number().min(0).max(100).optional(),
});

const createRecipeSchema = z.object({
  name: z.string().min(1),
  outputItemId: z.string().min(1),
  outputQty: z.number().positive(),
  outputUnit: z.string().min(1),
  notes: z.string().optional(),
  ingredients: z.array(ingredientSchema).min(1),
});

const updateRecipeSchema = z.object({
  name: z.string().min(1).optional(),
  outputQty: z.number().positive().optional(),
  outputUnit: z.string().min(1).optional(),
  notes: z.string().optional(),
  ingredients: z.array(ingredientSchema).min(1).optional(),
});

const calculateConsumptionSchema = z.object({
  itemId: z.string().min(1),
  quantity: z.number().positive(),
});

export async function recipesRoutes(app: FastifyInstance): Promise<void> {
  app.post('/recipes', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = createRecipeSchema.parse(request.body);
      const result = await recipesService.createRecipe(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });

  app.get('/recipes', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await recipesService.getRecipes(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/recipes/:id', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await recipesService.getRecipe(request.tenant.businessId, id);
      return reply.send(result);
    },
  });

  app.put('/recipes/:id', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = updateRecipeSchema.parse(request.body);
      const result = await recipesService.updateRecipe(request.tenant.businessId, id, body);
      return reply.send(result);
    },
  });

  app.delete('/recipes/:id', {
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await recipesService.deleteRecipe(request.tenant.businessId, id);
      return reply.send({ message: 'Recipe deleted successfully' });
    },
  });

  app.post('/recipes/calculate-consumption', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const body = calculateConsumptionSchema.parse(request.body);
      const result = await recipesService.calculateConsumption(
        request.tenant.businessId,
        body.itemId,
        body.quantity,
      );
      return reply.send(result);
    },
  });
}
