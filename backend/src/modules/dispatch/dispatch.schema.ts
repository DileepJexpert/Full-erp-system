import { z } from 'zod';

export const createDispatchSchema = z.object({
  locationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  items: z.array(z.object({
    itemId: z.string(),
    quantity: z.number().int().positive(),
  })).min(1),
  notes: z.string().optional(),
});

export const confirmDispatchSchema = z.object({
  dispatchId: z.string(),
});

export const dispatchQuerySchema = z.object({
  locationId: z.string().optional(),
  status: z.enum(['PENDING', 'CONFIRMED', 'RECONCILED']).optional(),
  date: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type CreateDispatchInput = z.infer<typeof createDispatchSchema>;
export type DispatchQuery = z.infer<typeof dispatchQuerySchema>;
