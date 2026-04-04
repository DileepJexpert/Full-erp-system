import type { FastifyInstance } from 'fastify';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { NotFoundError, BadRequestError, ConflictError } from '../../utils/errors.js';
import * as marketplaceService from './marketplace.service.js';

export async function marketplaceRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // ─── GET /marketplace/listings ──────────────────────────────
  app.get('/marketplace/listings', {
    schema: {
      tags: ['Marketplace'],
      summary: 'Search marketplace listings',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          category: { type: 'string' },
          city: { type: 'string' },
          minPrice: { type: 'number', minimum: 0 },
          maxPrice: { type: 'number', minimum: 0 },
          search: { type: 'string' },
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    handler: async (request, reply) => {
      const query = request.query as {
        category?: string;
        city?: string;
        minPrice?: number;
        maxPrice?: number;
        search?: string;
        page?: number;
        limit?: number;
      };
      const result = await marketplaceService.searchListings(query);
      return reply.send(result);
    },
  });

  // ─── GET /marketplace/listings/:id ──────────────────────────
  app.get('/marketplace/listings/:id', {
    schema: {
      tags: ['Marketplace'],
      summary: 'Get listing detail with supplier info',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const listing = await prisma.supplierListing.findUnique({
        where: { id },
        include: {
          supplier: {
            select: {
              id: true,
              businessName: true,
              description: true,
              phone: true,
              address: true,
              city: true,
              deliveryRadius: true,
              rating: true,
              totalOrders: true,
              isVerified: true,
            },
          },
        },
      });
      if (!listing || !listing.isActive) {
        throw new NotFoundError('SupplierListing', id);
      }
      return reply.send(listing);
    },
  });

  // ─── POST /marketplace/orders ───────────────────────────────
  app.post('/marketplace/orders', {
    schema: {
      tags: ['Marketplace'],
      summary: 'Create a marketplace order',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          supplierId: { type: 'string' },
          items: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              properties: {
                listingId: { type: 'string' },
                quantity: { type: 'number', exclusiveMinimum: 0 },
              },
              required: ['listingId', 'quantity'],
            },
          },
        },
        required: ['supplierId', 'items'],
      },
    },
    handler: async (request, reply) => {
      const body = request.body as {
        supplierId: string;
        items: Array<{ listingId: string; quantity: number }>;
      };
      const order = await marketplaceService.createOrder(
        request.tenant.businessId,
        body.supplierId,
        body.items,
      );
      return reply.code(201).send(order);
    },
  });

  // ─── GET /marketplace/orders ────────────────────────────────
  app.get('/marketplace/orders', {
    schema: {
      tags: ['Marketplace'],
      summary: 'List buyer orders',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    handler: async (request, reply) => {
      const { page = 1, limit = 20 } = request.query as { page?: number; limit?: number };
      const skip = (page - 1) * limit;

      const [orders, total] = await Promise.all([
        prisma.marketplaceOrder.findMany({
          where: { businessId: request.tenant.businessId },
          skip,
          take: limit,
          orderBy: { createdAt: 'desc' },
          include: {
            supplier: { select: { id: true, businessName: true } },
            items: true,
          },
        }),
        prisma.marketplaceOrder.count({
          where: { businessId: request.tenant.businessId },
        }),
      ]);

      return reply.send({
        data: orders,
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      });
    },
  });

  // ─── GET /marketplace/orders/:id ────────────────────────────
  app.get('/marketplace/orders/:id', {
    schema: {
      tags: ['Marketplace'],
      summary: 'Get order detail with items and status',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const order = await prisma.marketplaceOrder.findFirst({
        where: { id, businessId: request.tenant.businessId },
        include: {
          supplier: {
            select: { id: true, businessName: true, phone: true, city: true },
          },
          items: true,
        },
      });
      if (!order) throw new NotFoundError('MarketplaceOrder', id);
      return reply.send(order);
    },
  });

  // ─── POST /marketplace/ratings ──────────────────────────────
  app.post('/marketplace/ratings', {
    schema: {
      tags: ['Marketplace'],
      summary: 'Rate a supplier (one rating per business per supplier)',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          supplierId: { type: 'string' },
          rating: { type: 'integer', minimum: 1, maximum: 5 },
          review: { type: 'string' },
        },
        required: ['supplierId', 'rating'],
      },
    },
    handler: async (request, reply) => {
      const body = request.body as { supplierId: string; rating: number; review?: string };
      const businessId = request.tenant.businessId;

      // Check supplier exists
      const supplier = await prisma.supplierProfile.findUnique({
        where: { id: body.supplierId },
      });
      if (!supplier) throw new NotFoundError('SupplierProfile', body.supplierId);

      // Check for existing rating
      const existing = await prisma.supplierRating.findUnique({
        where: { businessId_supplierId: { businessId, supplierId: body.supplierId } },
      });
      if (existing) {
        throw new ConflictError('You have already rated this supplier. Use PUT to update.');
      }

      const rating = await prisma.supplierRating.create({
        data: {
          rating: body.rating,
          review: body.review,
          businessId,
          supplierId: body.supplierId,
        },
      });

      // Recalculate supplier average rating
      const agg = await prisma.supplierRating.aggregate({
        where: { supplierId: body.supplierId },
        _avg: { rating: true },
      });
      await prisma.supplierProfile.update({
        where: { id: body.supplierId },
        data: { rating: Math.round((agg._avg.rating ?? 0) * 100) / 100 },
      });

      return reply.code(201).send(rating);
    },
  });
}
