import type { FastifyInstance } from 'fastify';
import crypto from 'node:crypto';
import { z } from 'zod';
import { getEnv } from '../../config/env.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';
import * as whatsappService from './whatsapp.service.js';

// ── Zod schemas ──────────────────────────────────────────────────

const sendTemplateSchema = z.object({
  phone: z.string().min(10).max(15),
  templateId: z.string().min(1),
  params: z.record(z.string()).default({}),
});

const broadcastSchema = z.object({
  phones: z.array(z.string().min(10).max(15)).min(1).max(1000),
  message: z.string().min(1).max(4096),
});

// ── Helpers ──────────────────────────────────────────────────────

function verifyGupshupSignature(
  rawBody: string | Buffer,
  signatureHeader: string | undefined,
  secret: string,
): boolean {
  if (!signatureHeader) return false;

  const computed = crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(computed, 'hex'),
    Buffer.from(signatureHeader, 'hex'),
  );
}

// ── Routes ───────────────────────────────────────────────────────

export async function whatsappRoutes(app: FastifyInstance): Promise<void> {
  /**
   * POST /whatsapp/webhook
   * Receives inbound messages from Gupshup.
   * Verifies HMAC-SHA256, returns 200 immediately, processes async.
   */
  app.post('/whatsapp/webhook', {
    schema: {
      tags: ['WhatsApp'],
      summary: 'Inbound message webhook from Gupshup',
    },
    handler: async (request, reply) => {
      const env = getEnv();

      // Verify signature
      const signature = request.headers['x-gupshup-signature'] as string | undefined;
      const rawBody =
        typeof request.body === 'string'
          ? request.body
          : JSON.stringify(request.body);

      if (
        env.NODE_ENV === 'production' &&
        !verifyGupshupSignature(rawBody, signature, env.GUPSHUP_WEBHOOK_SECRET)
      ) {
        return reply.code(401).send({ error: 'Invalid signature' });
      }

      // Return 200 immediately
      reply.code(200).send({ status: 'ok' });

      // Process asynchronously
      try {
        const payload = typeof request.body === 'string'
          ? JSON.parse(request.body)
          : request.body;

        // Gupshup inbound payload structure
        const messagePayload = payload?.payload;
        if (!messagePayload || payload?.type !== 'message') {
          return;
        }

        const phone: string = messagePayload.source ?? messagePayload.sender?.phone ?? '';
        const text: string =
          messagePayload.payload?.text ??
          messagePayload.payload?.body ??
          messagePayload.text ??
          '';
        const waMessageId: string = messagePayload.id ?? '';

        if (!phone || !text) return;

        // Fire-and-forget async processing
        whatsappService.processInboundMessage(phone, text, waMessageId).catch((err) => {
          console.error('[WhatsApp Webhook] Processing error:', err);
        });
      } catch (err) {
        console.error('[WhatsApp Webhook] Parse error:', err);
      }
    },
  });

  /**
   * GET /whatsapp/sessions
   * List active WhatsApp sessions. Owner only.
   */
  app.get('/whatsapp/sessions', {
    schema: {
      tags: ['WhatsApp'],
      summary: 'List active WhatsApp sessions',
      security: [{ bearerAuth: [] }],
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const sessions = await whatsappService.listSessions(
        request.tenant.businessId,
      );
      return reply.send({ data: sessions });
    },
  });

  /**
   * POST /whatsapp/send-template
   * Send a WhatsApp template to a phone number. Owner only.
   */
  app.post('/whatsapp/send-template', {
    schema: {
      tags: ['WhatsApp'],
      summary: 'Send WhatsApp template message',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          phone: { type: 'string' },
          templateId: { type: 'string' },
          params: { type: 'object', additionalProperties: { type: 'string' } },
        },
        required: ['phone', 'templateId'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const body = sendTemplateSchema.parse(request.body);
      await whatsappService.sendTemplate(body.phone, body.templateId, body.params);
      return reply.send({ status: 'sent' });
    },
  });

  /**
   * POST /whatsapp/broadcast
   * Send a bulk text message to a customer list. Owner only.
   */
  app.post('/whatsapp/broadcast', {
    schema: {
      tags: ['WhatsApp'],
      summary: 'Broadcast message to customer list',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          phones: {
            type: 'array',
            items: { type: 'string' },
            minItems: 1,
            maxItems: 1000,
          },
          message: { type: 'string', minLength: 1, maxLength: 4096 },
        },
        required: ['phones', 'message'],
      },
    },
    preHandler: [authenticate, authorize('OWNER')],
    handler: async (request, reply) => {
      const body = broadcastSchema.parse(request.body);
      const result = await whatsappService.broadcastMessage(
        request.tenant.businessId,
        body.phones,
        body.message,
      );
      return reply.send(result);
    },
  });
}
