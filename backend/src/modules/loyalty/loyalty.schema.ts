import { z } from 'zod';

export const customerQuerySchema = z.object({
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export const createCustomerSchema = z.object({
  phone: z.string(),
  name: z.string().optional(),
});

export const redeemPointsSchema = z.object({
  customerId: z.string(),
  points: z.number().int().positive(),
});

export type CustomerQuery = z.infer<typeof customerQuerySchema>;
export type CreateCustomerInput = z.infer<typeof createCustomerSchema>;
