import { z } from 'zod';

export const recordCashSchema = z.object({
  locationId: z.string(),
  operatorId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  expectedCash: z.number().min(0),
  actualCollected: z.number().min(0),
  depositedAmount: z.number().min(0).optional(),
  bankRef: z.string().optional(),
  notes: z.string().optional(),
});

export const cashQuerySchema = z.object({
  locationId: z.string().optional(),
  operatorId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type RecordCashInput = z.infer<typeof recordCashSchema>;
export type CashQuery = z.infer<typeof cashQuerySchema>;
