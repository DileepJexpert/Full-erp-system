import { z } from 'zod';

export const computeSalarySchema = z.object({
  operatorId: z.string(),
  month: z.string().regex(/^\d{4}-\d{2}$/),
  bonus: z.number().min(0).default(0),
  adjustments: z.number().default(0),
  adjustmentNotes: z.string().optional(),
});

export const salaryQuerySchema = z.object({
  month: z.string().optional(),
  status: z.enum(['DRAFT', 'FINALIZED', 'PAID']).optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type ComputeSalaryInput = z.infer<typeof computeSalarySchema>;
export type SalaryQuery = z.infer<typeof salaryQuerySchema>;
