import { z } from 'zod';

export const createPurchaseSchema = z.object({
  supplierId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  items: z.array(z.object({
    itemId: z.string(),
    quantity: z.number().positive(),
    unitPrice: z.number().positive(),
  })).min(1),
  amountPaid: z.number().min(0).default(0),
  notes: z.string().optional(),
});

export const purchaseQuerySchema = z.object({
  supplierId: z.string().optional(),
  paymentStatus: z.enum(['PAID', 'PARTIAL', 'PENDING']).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export const recordPaymentSchema = z.object({
  amount: z.number().positive(),
});

export type CreatePurchaseInput = z.infer<typeof createPurchaseSchema>;
export type PurchaseQuery = z.infer<typeof purchaseQuerySchema>;
export type RecordPaymentInput = z.infer<typeof recordPaymentSchema>;
