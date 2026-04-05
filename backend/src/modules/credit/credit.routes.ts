import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as creditService from './credit.service.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authorize } from '../../middleware/authorize.js';

const creditSaleSchema = z.object({
  customerId: z.string().min(1),
  amount: z.number().positive(),
  billId: z.string().min(1),
  locationId: z.string().min(1),
});

const paymentSchema = z.object({
  customerId: z.string().min(1),
  amount: z.number().positive(),
  paymentMode: z.enum(['CASH', 'UPI', 'MIXED']),
  paymentRef: z.string().optional(),
});

const ledgerFiltersSchema = z.object({
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

export async function creditRoutes(app: FastifyInstance): Promise<void> {
  app.post('/credit/sale', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = creditSaleSchema.parse(request.body);
      const result = await creditService.addCreditSale(
        request.tenant.businessId,
        body.customerId,
        body.amount,
        body.billId,
        body.locationId,
        request.tenant.userId,
      );
      return reply.code(201).send(result);
    },
  });

  app.post('/credit/payment', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER', 'STAFF')],
    handler: async (request, reply) => {
      const body = paymentSchema.parse(request.body);
      const result = await creditService.receivePayment(
        request.tenant.businessId,
        body.customerId,
        body.amount,
        body.paymentMode,
        body.paymentRef,
        request.tenant.userId,
      );
      return reply.code(201).send(result);
    },
  });

  app.get('/credit/ledger/:customerId', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { customerId } = request.params as { customerId: string };
      const filters = ledgerFiltersSchema.parse(request.query);
      const result = await creditService.getCreditLedger(
        request.tenant.businessId,
        customerId,
        filters,
      );
      return reply.send(result);
    },
  });

  app.get('/credit/outstanding', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const result = await creditService.getOutstandingCustomers(request.tenant.businessId);
      return reply.send(result);
    },
  });

  app.get('/credit/summary/:customerId', {
    preHandler: [authenticate, authorize('OWNER', 'MANAGER')],
    handler: async (request, reply) => {
      const { customerId } = request.params as { customerId: string };
      const result = await creditService.getCustomerCreditSummary(
        request.tenant.businessId,
        customerId,
      );
      return reply.send(result);
    },
  });
}
