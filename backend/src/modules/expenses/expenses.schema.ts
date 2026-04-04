import { z } from 'zod';

export const createExpenseSchema = z.object({
  locationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  amount: z.number().positive(),
  category: z.enum(['FUEL', 'ICE', 'LOCAL_PURCHASE', 'REPAIR', 'LOCATION_CHARGE', 'TRANSPORT', 'ELECTRICITY', 'MISC']),
  description: z.string().min(1),
  receiptUrl: z.string().optional(),
});

export const expenseQuerySchema = z.object({
  locationId: z.string().optional(),
  category: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type CreateExpenseInput = z.infer<typeof createExpenseSchema>;
export type ExpenseQuery = z.infer<typeof expenseQuerySchema>;
