import { z } from 'zod';

export const checkInSchema = z.object({
  locationId: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  checkInLat: z.number().optional(),
  checkInLng: z.number().optional(),
  isSubstitute: z.boolean().default(false),
});

export const checkOutSchema = z.object({
  attendanceId: z.string(),
});

export const attendanceQuerySchema = z.object({
  locationId: z.string().optional(),
  operatorId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export type CheckInInput = z.infer<typeof checkInSchema>;
export type AttendanceQuery = z.infer<typeof attendanceQuerySchema>;
