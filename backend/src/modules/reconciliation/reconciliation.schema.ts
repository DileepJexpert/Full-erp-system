import { z } from 'zod';

export const createReconciliationSchema = z.object({
  dispatchId: z.string(),
  locationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  items: z.array(z.object({
    itemId: z.string(),
    sold: z.number().int().min(0),
    returned: z.number().int().min(0),
  })).min(1),
  notes: z.string().optional(),
});

export const reconQuerySchema = z.object({
  locationId: z.string().optional(),
  operatorId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type CreateReconciliationInput = z.infer<typeof createReconciliationSchema>;
export type ReconQuery = z.infer<typeof reconQuerySchema>;
