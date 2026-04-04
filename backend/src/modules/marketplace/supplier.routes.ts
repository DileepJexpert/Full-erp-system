import type { FastifyInstance } from 'fastify';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../../utils/errors.js';
import * as supplierService from './supplier.service.js';

export async function supplierRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // Helper to ensure the user has a SUPPLIER role
  function requireSupplier(role: string) {
    if (role !== 'SUPPLIER' && role !== 'OWNER') {
      throw new ForbiddenError('Only users with SUPPLIER role can access this endpoint');
    }
  }

  // Helper to get supplier profile for current user
  async function getProfileForUser(userId: string) {
    return prisma.supplierProfile.findUnique({ where: { userId } });
  }

  // ─── POST /marketplace-seller/profile ───────────────────────
  app.post('/marketplace-seller/profile', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Create supplier profile',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          businessName: { type: 'string', minLength: 1 },
          description: { type: 'string' },
          phone: { type: 'string', minLength: 1 },
          address: { type: 'string', minLength: 1 },
          city: { type: 'string', minLength: 1 },
          deliveryRadius: { type: 'integer', minimum: 1 },
        },
        required: ['businessName', 'phone', 'address', 'city'],
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const body = request.body as {
        businessName: string;
        description?: string;
        phone: string;
        address: string;
        city: string;
        deliveryRadius?: number;
      };

      // Check if profile already exists
      const existing = await getProfileForUser(request.tenant.userId);
      if (existing) {
        throw new BadRequestError('Supplier profile already exists. Use PUT to update.');
      }

      const profile = await prisma.supplierProfile.create({
        data: {
          userId: request.tenant.userId,
          businessName: body.businessName,
          description: body.description,
          phone: body.phone,
          address: body.address,
          city: body.city,
          deliveryRadius: body.deliveryRadius ?? 50,
        },
      });
      return reply.code(201).send(profile);
    },
  });

  // ─── GET /marketplace-seller/profile ────────────────────────
  app.get('/marketplace-seller/profile', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Get own supplier profile',
      security: [{ bearerAuth: [] }],
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const profile = await prisma.supplierProfile.findUnique({
        where: { userId: request.tenant.userId },
        include: { ratings: true },
      });
      if (!profile) throw new NotFoundError('SupplierProfile');
      return reply.send(profile);
    },
  });

  // ─── PUT /marketplace-seller/profile ────────────────────────
  app.put('/marketplace-seller/profile', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Update supplier profile',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          businessName: { type: 'string', minLength: 1 },
          description: { type: 'string' },
          phone: { type: 'string' },
          address: { type: 'string' },
          city: { type: 'string' },
          deliveryRadius: { type: 'integer', minimum: 1 },
        },
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const body = request.body as Record<string, unknown>;

      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const updated = await prisma.supplierProfile.update({
        where: { userId: request.tenant.userId },
        data: {
          ...(body.businessName !== undefined && { businessName: body.businessName as string }),
          ...(body.description !== undefined && { description: body.description as string }),
          ...(body.phone !== undefined && { phone: body.phone as string }),
          ...(body.address !== undefined && { address: body.address as string }),
          ...(body.city !== undefined && { city: body.city as string }),
          ...(body.deliveryRadius !== undefined && { deliveryRadius: body.deliveryRadius as number }),
        },
      });
      return reply.send(updated);
    },
  });

  // ─── POST /marketplace-seller/listings ──────────────────────
  app.post('/marketplace-seller/listings', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Create a listing',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          name: { type: 'string', minLength: 1 },
          description: { type: 'string' },
          category: { type: 'string', minLength: 1 },
          unit: { type: 'string', minLength: 1 },
          pricePerUnit: { type: 'number', exclusiveMinimum: 0 },
          minOrderQty: { type: 'number', exclusiveMinimum: 0 },
          maxOrderQty: { type: 'number', exclusiveMinimum: 0 },
          bulkPrice: { type: 'number', exclusiveMinimum: 0 },
          bulkThreshold: { type: 'number', exclusiveMinimum: 0 },
          imageUrl: { type: 'string' },
        },
        required: ['name', 'category', 'unit', 'pricePerUnit', 'minOrderQty'],
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const body = request.body as {
        name: string;
        description?: string;
        category: string;
        unit: string;
        pricePerUnit: number;
        minOrderQty: number;
        maxOrderQty?: number;
        bulkPrice?: number;
        bulkThreshold?: number;
        imageUrl?: string;
      };

      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const listing = await prisma.supplierListing.create({
        data: {
          name: body.name,
          description: body.description,
          category: body.category,
          unit: body.unit,
          pricePerUnit: body.pricePerUnit,
          minOrderQty: body.minOrderQty,
          maxOrderQty: body.maxOrderQty,
          bulkPrice: body.bulkPrice,
          bulkThreshold: body.bulkThreshold,
          imageUrl: body.imageUrl,
          supplierId: profile.id,
        },
      });
      return reply.code(201).send(listing);
    },
  });

  // ─── GET /marketplace-seller/listings ───────────────────────
  app.get('/marketplace-seller/listings', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'List own listings',
      security: [{ bearerAuth: [] }],
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const listings = await prisma.supplierListing.findMany({
        where: { supplierId: profile.id },
        orderBy: { createdAt: 'desc' },
      });
      return reply.send(listings);
    },
  });

  // ─── PUT /marketplace-seller/listings/:id ───────────────────
  app.put('/marketplace-seller/listings/:id', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Update a listing',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
      body: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          description: { type: 'string' },
          category: { type: 'string' },
          unit: { type: 'string' },
          pricePerUnit: { type: 'number', exclusiveMinimum: 0 },
          minOrderQty: { type: 'number', exclusiveMinimum: 0 },
          maxOrderQty: { type: 'number', exclusiveMinimum: 0 },
          bulkPrice: { type: 'number', exclusiveMinimum: 0 },
          bulkThreshold: { type: 'number', exclusiveMinimum: 0 },
          imageUrl: { type: 'string' },
        },
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const { id } = request.params as { id: string };
      const body = request.body as Record<string, unknown>;

      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const listing = await prisma.supplierListing.findFirst({
        where: { id, supplierId: profile.id },
      });
      if (!listing) throw new NotFoundError('SupplierListing', id);

      const updated = await prisma.supplierListing.update({
        where: { id },
        data: {
          ...(body.name !== undefined && { name: body.name as string }),
          ...(body.description !== undefined && { description: body.description as string }),
          ...(body.category !== undefined && { category: body.category as string }),
          ...(body.unit !== undefined && { unit: body.unit as string }),
          ...(body.pricePerUnit !== undefined && { pricePerUnit: body.pricePerUnit as number }),
          ...(body.minOrderQty !== undefined && { minOrderQty: body.minOrderQty as number }),
          ...(body.maxOrderQty !== undefined && { maxOrderQty: body.maxOrderQty as number }),
          ...(body.bulkPrice !== undefined && { bulkPrice: body.bulkPrice as number }),
          ...(body.bulkThreshold !== undefined && { bulkThreshold: body.bulkThreshold as number }),
          ...(body.imageUrl !== undefined && { imageUrl: body.imageUrl as string }),
        },
      });
      return reply.send(updated);
    },
  });

  // ─── DELETE /marketplace-seller/listings/:id ────────────────
  app.delete('/marketplace-seller/listings/:id', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Deactivate a listing (soft delete)',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const { id } = request.params as { id: string };

      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const listing = await prisma.supplierListing.findFirst({
        where: { id, supplierId: profile.id },
      });
      if (!listing) throw new NotFoundError('SupplierListing', id);

      await prisma.supplierListing.update({
        where: { id },
        data: { isActive: false },
      });
      return reply.send({ success: true });
    },
  });

  // ─── GET /marketplace-seller/orders ─────────────────────────
  app.get('/marketplace-seller/orders', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'List orders received as a supplier',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          status: { type: 'string' },
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const { status, page = 1, limit = 20 } = request.query as {
        status?: string;
        page?: number;
        limit?: number;
      };
      const skip = (page - 1) * limit;

      const where: Record<string, unknown> = { supplierId: profile.id };
      if (status) where.status = status;

      const [orders, total] = await Promise.all([
        prisma.marketplaceOrder.findMany({
          where,
          skip,
          take: limit,
          orderBy: { createdAt: 'desc' },
          include: { items: true },
        }),
        prisma.marketplaceOrder.count({ where }),
      ]);

      return reply.send({
        data: orders,
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      });
    },
  });

  // ─── PUT /marketplace-seller/orders/:id/status ──────────────
  app.put('/marketplace-seller/orders/:id/status', {
    schema: {
      tags: ['Marketplace Seller'],
      summary: 'Update order status',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: { id: { type: 'string' } },
        required: ['id'],
      },
      body: {
        type: 'object',
        properties: {
          status: {
            type: 'string',
            enum: ['CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'],
          },
        },
        required: ['status'],
      },
    },
    handler: async (request, reply) => {
      requireSupplier(request.tenant.role);
      const { id } = request.params as { id: string };
      const { status } = request.body as { status: string };

      const profile = await getProfileForUser(request.tenant.userId);
      if (!profile) throw new NotFoundError('SupplierProfile');

      const updated = await supplierService.updateOrderStatus(profile.id, id, status);
      return reply.send(updated);
    },
  });
}
