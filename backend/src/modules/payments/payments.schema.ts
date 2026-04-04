import { z } from 'zod';

export const createQrSchema = z.object({
  billId: z.string(),
  amount: z.number().positive(),
  description: z.string().optional(),
  customerName: z.string().optional(),
});

export const createOrderSchema = z.object({
  billId: z.string(),
  amount: z.number().positive(),
});

export type CreateQrInput = z.infer<typeof createQrSchema>;
export type CreateOrderInput = z.infer<typeof createOrderSchema>;
