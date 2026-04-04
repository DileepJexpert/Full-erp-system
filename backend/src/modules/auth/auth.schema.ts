import { z } from 'zod';

export const sendOtpSchema = z.object({
  phone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid Indian mobile number'),
});

export const verifyOtpSchema = z.object({
  phone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid Indian mobile number'),
  otp: z.string().length(6, 'OTP must be 6 digits'),
  businessId: z.string().optional(),
});

export const registerBusinessSchema = z.object({
  businessName: z.string().min(2).max(100),
  businessType: z.enum([
    'FOOD_KIOSK', 'CLOUD_KITCHEN', 'BAKERY', 'LAUNDRY', 'COACHING',
    'PHARMACY_CHAIN', 'RENTAL', 'SERVICE', 'KIRANA', 'OTHER',
  ]),
  ownerName: z.string().min(2).max(100),
  phone: z.string().regex(/^[6-9]\d{9}$/),
  email: z.string().email().optional(),
});

export const addUserSchema = z.object({
  name: z.string().min(2).max(100),
  phone: z.string().regex(/^[6-9]\d{9}$/),
  role: z.enum(['MANAGER', 'STAFF']),
  salaryType: z.enum(['FIXED', 'ATTENDANCE_BASED']).default('FIXED'),
  baseSalary: z.number().min(0).default(0),
  aadhaar: z.string().optional(),
  language: z.string().default('en'),
});

export type SendOtpInput = z.infer<typeof sendOtpSchema>;
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>;
export type RegisterBusinessInput = z.infer<typeof registerBusinessSchema>;
export type AddUserInput = z.infer<typeof addUserSchema>;
