import { z } from 'zod';

export const createSupplierSchema = z.object({
  name: z.string().min(1),
  phone: z.string(),
  address: z.string().optional(),
  paymentTerms: z.enum(['CASH', 'CREDIT_7', 'CREDIT_15', 'CREDIT_30']).default('CASH'),
});

export const updateSupplierSchema = createSupplierSchema.partial();

export type CreateSupplierInput = z.infer<typeof createSupplierSchema>;
export type UpdateSupplierInput = z.infer<typeof updateSupplierSchema>;
