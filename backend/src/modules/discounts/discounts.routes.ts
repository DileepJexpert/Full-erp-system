import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as discountsService from './discounts.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const discountTypeEnum = z.enum([
  'PERCENTAGE_OFF', 'FLAT_OFF', 'BUY_X_GET_Y', 'MIN_CART_VALUE', 'MEMBER_TIER', 'FLASH_SALE',
]);

const createRuleSchema = z.object({
  name: z.string().min(1),
  type: discountTypeEnum,
  value: z.number().positive(),
  minCartValue: z.number().positive().optional(),
  maxDiscount: z.number().positive().optional(),
  buyQty: z.number().int().positive().optional(),
  getQty: z.number().int().positive().optional(),
  applicableItems: z.array(z.string()).optional(),
  applicableCats: z.array(z.string()).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  maxUsage: z.number().int().positive().optional(),
  locationId: z.string().optional(),
});

const updateRuleSchema = z.object({
  name: z.string().min(1).optional(),
  type: discountTypeEnum.optional(),
  value: z.number().positive().optional(),
  minCartValue: z.number().positive().nullable().optional(),
  maxDiscount: z.number().positive().nullable().optional(),
  buyQty: z.number().int().positive().nullable().optional(),
  getQty: z.number().int().positive().nullable().optional(),
  applicableItems: z.array(z.string()).optional(),
  applicableCats: z.array(z.string()).optional(),
  startDate: z.string().nullable().optional(),
  endDate: z.string().nullable().optional(),
  isActive: z.boolean().optional(),
  maxUsage: z.number().int().positive().nullable().optional(),
  locationId: z.string().nullable().optional(),
});

const createCouponSchema = z.object({
  code: z.string().min(1).max(50),
  discountRuleId: z.string().min(1),
  maxRedemptions: z.number().int().positive().optional(),
  expiresAt: z.string().optional(),
});

const validateCouponSchema = z.object({
  code: z.string().min(1),
});

const cartItemSchema = z.object({
  itemId: z.string().min(1),
  quantity: z.number().positive(),
  unitPrice: z.number().positive(),
  category: z.string().optional(),
});

const calculateDiscountSchema = z.object({
  cartItems: z.array(cartItemSchema).min(1),
  couponCode: z.string().optional(),
});

export async function discountsRoutes(app: FastifyInstance): Promise<void> {
  app.post('/discounts/rules', {
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const body = createRuleSchema.parse(request.body);
      const result = await discountsService.createDiscountRule(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });

  app.get('/discounts/rules', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await discountsService.getDiscountRules(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.put('/discounts/rules/:id', {
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = updateRuleSchema.parse(request.body);
      const result = await discountsService.updateDiscountRule(request.tenant.businessId, id, body);
      return reply.send(result);
    },
  });

  app.delete('/discounts/rules/:id', {
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      await discountsService.deleteDiscountRule(request.tenant.businessId, id);
      return reply.send({ message: 'Discount rule deleted successfully' });
    },
  });

  app.post('/discounts/coupons', {
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const body = createCouponSchema.parse(request.body);
      const result = await discountsService.createCoupon(request.tenant.businessId, body);
      return reply.code(201).send(result);
    },
  });

  app.post('/discounts/validate', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = validateCouponSchema.parse(request.body);
      const result = await discountsService.validateCoupon(request.tenant.businessId, body.code);
      return reply.send(result);
    },
  });

  app.post('/discounts/calculate', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = calculateDiscountSchema.parse(request.body);
      const result = await discountsService.calculateDiscount(
        request.tenant.businessId,
        body.cartItems,
        body.couponCode,
      );
      return reply.send(result);
    },
  });
}
