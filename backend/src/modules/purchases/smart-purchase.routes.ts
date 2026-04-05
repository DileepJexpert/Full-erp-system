import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import { scanBill, parseTextBill, parseVoiceTranscript } from './bill-scanner.service.js';
import { validatePrices } from './price-validator.js';
import { checkDuplicate } from './duplicate-detector.js';
import { fuzzyMatchItems } from './fuzzy-matcher.js';
import { savePurchaseWithSmartFeatures } from './smart-purchase.service.js';

/* ── Zod schemas ───────────────────────────────────────────────── */

const scanBillSchema = z.object({
  image: z.string().min(1),
});

const parseTextSchema = z.object({
  text: z.string().min(1),
});

const parseVoiceSchema = z.object({
  transcript: z.string().min(1),
});

const repeatLastSchema = z.object({
  supplierId: z.string().min(1),
});

const batchItemSchema = z.object({
  itemId: z.string(),
  quantity: z.number().positive(),
  unitPrice: z.number().positive(),
});

const batchPurchaseSchema = z.object({
  supplierId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  items: z.array(batchItemSchema).min(1),
  notes: z.string().optional(),
  entryMethod: z.string(),
  billPhotoUrl: z.string().optional(),
  billPhotoKey: z.string().optional(),
  aiExtractedRaw: z.any().optional(),
  aiConfidence: z.number().optional(),
  voiceTranscript: z.string().optional(),
  locationId: z.string().optional(),
});

const batchSaveSchema = z.object({
  purchases: z.array(batchPurchaseSchema).min(1),
});

const barcodeQuerySchema = z.object({
  barcode: z.string().min(1),
});

const rejectSchema = z.object({
  reason: z.string().min(1),
});

const templateQuerySchema = z.object({
  supplierId: z.string().optional(),
});

const createTemplateSchema = z.object({
  name: z.string().min(1),
  supplierId: z.string().min(1),
  items: z.any(),
});

const itemsMatchSchema = z.object({
  names: z.array(z.string()).min(1),
});

/* ── Routes ────────────────────────────────────────────────────── */

export async function smartPurchaseRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  // ─── POST /purchases/scan-bill ──────────────────────────────
  app.post('/purchases/scan-bill', {
    schema: { tags: ['Smart Purchases'], summary: 'Upload bill image and get extracted data', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { image } = scanBillSchema.parse(request.body);
      const { businessId } = request.tenant;

      const extracted = await scanBill(image, businessId);
      const priceAlerts = await validatePrices(extracted.items, businessId);
      const duplicateResult = await checkDuplicate({
        businessId,
        supplierId: extracted.supplier?.matchedId ?? null,
        date: extracted.billDate ? new Date(extracted.billDate) : new Date(),
        totalAmount: extracted.grandTotal,
      });

      return reply.send({
        extracted,
        priceAlerts,
        isDuplicate: duplicateResult.isDuplicate,
        duplicateInfo: duplicateResult,
      });
    },
  });

  // ─── POST /purchases/parse-text ─────────────────────────────
  app.post('/purchases/parse-text', {
    schema: { tags: ['Smart Purchases'], summary: 'Parse text bill (WhatsApp style)', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { text } = parseTextSchema.parse(request.body);
      const { businessId } = request.tenant;

      const extracted = await parseTextBill(text, businessId);
      const priceAlerts = await validatePrices(extracted.items, businessId);
      const duplicateResult = await checkDuplicate({
        businessId,
        supplierId: extracted.supplier?.matchedId ?? null,
        date: extracted.billDate ? new Date(extracted.billDate) : new Date(),
        totalAmount: extracted.grandTotal,
      });

      return reply.send({
        extracted,
        priceAlerts,
        isDuplicate: duplicateResult.isDuplicate,
        duplicateInfo: duplicateResult,
      });
    },
  });

  // ─── POST /purchases/parse-voice ────────────────────────────
  app.post('/purchases/parse-voice', {
    schema: { tags: ['Smart Purchases'], summary: 'Parse voice transcript', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { transcript } = parseVoiceSchema.parse(request.body);
      const { businessId } = request.tenant;

      const extracted = await parseVoiceTranscript(transcript, businessId);
      const priceAlerts = await validatePrices(extracted.items, businessId);
      const duplicateResult = await checkDuplicate({
        businessId,
        supplierId: extracted.supplier?.matchedId ?? null,
        date: extracted.billDate ? new Date(extracted.billDate) : new Date(),
        totalAmount: extracted.grandTotal,
      });

      return reply.send({
        extracted,
        priceAlerts,
        isDuplicate: duplicateResult.isDuplicate,
        duplicateInfo: duplicateResult,
      });
    },
  });

  // ─── POST /purchases/repeat-last ────────────────────────────
  app.post('/purchases/repeat-last', {
    schema: { tags: ['Smart Purchases'], summary: 'Get last purchase for supplier (pre-fill)', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { supplierId } = repeatLastSchema.parse(request.body);
      const { businessId } = request.tenant;

      const lastPurchase = await prisma.purchase.findFirst({
        where: { businessId, supplierId },
        orderBy: { createdAt: 'desc' },
        include: {
          items: { include: { item: true } },
          supplier: { select: { id: true, name: true } },
        },
      });

      return reply.send(lastPurchase ?? null);
    },
  });

  // ─── POST /purchases/batch-save ─────────────────────────────
  app.post('/purchases/batch-save', {
    schema: { tags: ['Smart Purchases'], summary: 'Save multiple purchases atomically', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { purchases } = batchSaveSchema.parse(request.body);
      const { businessId, userId, role: userRole } = request.tenant;

      const results: any[] = [];
      for (const purchaseInput of purchases) {
        const result = await savePurchaseWithSmartFeatures(
          businessId,
          userId,
          userRole,
          purchaseInput,
        );
        results.push(result);
      }

      return reply.code(201).send({
        saved: results.length,
        purchases: results.map((r) => r.purchase),
        suggestions: results
          .filter((r) => r.suggestTemplate)
          .map((r) => ({
            supplierId: r.purchase.supplierId,
            message: 'Consider creating a template for this supplier',
          })),
      });
    },
  });

  // ─── GET /purchases/lookup-barcode ──────────────────────────
  app.get('/purchases/lookup-barcode', {
    schema: { tags: ['Smart Purchases'], summary: 'Lookup item by barcode', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { barcode } = barcodeQuerySchema.parse(request.query);
      const { businessId } = request.tenant;

      const item = await prisma.item.findFirst({
        where: { barcode, businessId, isActive: true },
      });

      return reply.send({ found: !!item, item: item ?? undefined });
    },
  });

  // ─── PUT /purchases/:id/approve ─────────────────────────────
  app.put('/purchases/:id/approve', {
    schema: { tags: ['Smart Purchases'], summary: 'Owner approves pending purchase', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const { businessId, userId } = request.tenant;

      const purchase = await prisma.purchase.findFirst({
        where: { id, businessId, approvalStatus: 'PENDING_APPROVAL' },
        include: { items: true },
      });
      if (!purchase) {
        throw new NotFoundError('Pending purchase', id);
      }

      // Update approval status and stock in a transaction
      const updated = await prisma.$transaction(async (tx) => {
        const approvedPurchase = await tx.purchase.update({
          where: { id },
          data: {
            approvalStatus: 'APPROVED',
            approvedById: userId,
            approvedAt: new Date(),
          },
          include: {
            items: { include: { item: true } },
            supplier: { select: { id: true, name: true } },
          },
        });

        // Now update stock for each item
        for (const lineItem of purchase.items) {
          const existingItem = await tx.item.findUnique({
            where: { id: lineItem.itemId },
            select: { avgPurchasePrice: true },
          });

          await tx.item.update({
            where: { id: lineItem.itemId },
            data: {
              centralStock: { increment: lineItem.quantity },
              lastPurchasePrice: lineItem.unitPrice,
              avgPurchasePrice:
                existingItem?.avgPurchasePrice != null
                  ? existingItem.avgPurchasePrice * 0.8 + lineItem.unitPrice * 0.2
                  : lineItem.unitPrice,
            },
          });
        }

        return approvedPurchase;
      });

      return reply.send(updated);
    },
  });

  // ─── PUT /purchases/:id/reject ──────────────────────────────
  app.put('/purchases/:id/reject', {
    schema: { tags: ['Smart Purchases'], summary: 'Owner rejects pending purchase', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('OWNER')],
    handler: async (request, reply) => {
      const { id } = request.params as { id: string };
      const { reason } = rejectSchema.parse(request.body);
      const { businessId } = request.tenant;

      const purchase = await prisma.purchase.findFirst({
        where: { id, businessId, approvalStatus: 'PENDING_APPROVAL' },
      });
      if (!purchase) {
        throw new NotFoundError('Pending purchase', id);
      }

      const updated = await prisma.purchase.update({
        where: { id },
        data: {
          approvalStatus: 'REJECTED',
          rejectionReason: reason,
        },
        include: {
          items: { include: { item: true } },
          supplier: { select: { id: true, name: true } },
        },
      });

      return reply.send(updated);
    },
  });

  // ─── GET /purchase-templates ────────────────────────────────
  app.get('/purchase-templates', {
    schema: { tags: ['Smart Purchases'], summary: 'List templates for business', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const query = templateQuerySchema.parse(request.query);
      const { businessId } = request.tenant;

      const where: Record<string, unknown> = { businessId };
      if (query.supplierId) where.supplierId = query.supplierId;

      const templates = await prisma.purchaseTemplate.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
      });

      return reply.send(templates);
    },
  });

  // ─── POST /purchase-templates ───────────────────────────────
  app.post('/purchase-templates', {
    schema: { tags: ['Smart Purchases'], summary: 'Create/save a purchase template', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const body = createTemplateSchema.parse(request.body);
      const { businessId } = request.tenant;

      const template = await prisma.purchaseTemplate.create({
        data: {
          businessId,
          name: body.name,
          supplierId: body.supplierId,
          items: body.items,
        },
      });

      return reply.code(201).send(template);
    },
  });

  // ─── POST /items/match ──────────────────────────────────────
  app.post('/items/match', {
    schema: { tags: ['Smart Purchases'], summary: 'Fuzzy match item names to inventory', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { names } = itemsMatchSchema.parse(request.body);
      const { businessId } = request.tenant;

      const matchMap = await fuzzyMatchItems(names, businessId);

      // Convert Map to array of results
      const matches = names.map((name) => ({
        input: name,
        match: matchMap.get(name) ?? null,
      }));

      return reply.send(matches);
    },
  });

  // ─── GET /items/aliases ─────────────────────────────────────
  app.get('/items/aliases', {
    schema: { tags: ['Smart Purchases'], summary: 'Get global + business item aliases', security: [{ bearerAuth: [] }] },
    preHandler: [authorize('STAFF', 'MANAGER', 'OWNER')],
    handler: async (request, reply) => {
      const { businessId } = request.tenant;

      const [globalAliases, businessItems] = await Promise.all([
        prisma.itemAliasGlobal.findMany(),
        prisma.item.findMany({
          where: { businessId, isActive: true },
          select: { id: true, name: true, aliases: true },
        }),
      ]);

      return reply.send({
        global: globalAliases,
        business: businessItems,
      });
    },
  });
}
