import { z } from 'zod';

export const createBillSchema = z.object({
  locationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  items: z.array(z.object({
    itemId: z.string(),
    quantity: z.number().int().positive(),
    unitPrice: z.number().positive(),
  })).min(1),
  paymentMode: z.enum(['CASH', 'UPI', 'MIXED']).default('CASH'),
  cashAmount: z.number().min(0).default(0),
  upiAmount: z.number().min(0).default(0),
  upiTransactionRef: z.string().optional(),
  orderSource: z.enum(['WALK_IN', 'SWIGGY', 'ZOMATO', 'PHONE_ORDER', 'OTHER']).default('WALK_IN'),
  aggregatorOrderId: z.string().optional(),
  aggregatorCommission: z.number().min(0).default(0),
  customerPhone: z.string().optional(),
  customerName: z.string().optional(),
  loyaltyPointsRedeemed: z.number().int().min(0).default(0),
  notes: z.string().optional(),
});

export const billQuerySchema = z.object({
  locationId: z.string().optional(),
  date: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type CreateBillInput = z.infer<typeof createBillSchema>;
export type BillQuery = z.infer<typeof billQuerySchema>;
