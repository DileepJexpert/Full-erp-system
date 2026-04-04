import { z } from 'zod';

export const createItemSchema = z.object({
  name: z.string().min(1).max(200),
  unit: z.string().min(1),
  costPrice: z.number().positive(),
  sellPrice: z.number().min(0).default(0),
  category: z.enum(['FOOD', 'BEVERAGE', 'SUPPLY', 'PACKAGING', 'MEDICINE', 'SERVICE', 'OTHER']).default('FOOD'),
  gstRate: z.number().min(0).default(5),
  hsnCode: z.string().optional(),
  dailyMargin: z.number().int().min(0).default(0),
  seasonTags: z.array(z.enum(['WINTER', 'SUMMER', 'MONSOON', 'FESTIVAL', 'ALL_YEAR'])).default(['ALL_YEAR']),
  isPerishable: z.boolean().default(false),
  shelfLifeHrs: z.number().int().positive().optional(),
  centralStock: z.number().min(0).default(0),
  minStockLevel: z.number().min(0).optional(),
});

export const updateItemSchema = createItemSchema.partial();

export const itemQuerySchema = z.object({
  category: z.string().optional(),
  isActive: z.coerce.boolean().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export type CreateItemInput = z.infer<typeof createItemSchema>;
export type UpdateItemInput = z.infer<typeof updateItemSchema>;
export type ItemQuery = z.infer<typeof itemQuerySchema>;
