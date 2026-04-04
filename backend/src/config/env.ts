import { z } from 'zod';

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(16),
  JWT_EXPIRY: z.string().default('7d'),
  MSG91_AUTH_KEY: z.string().default('mock-key'),
  MSG91_TEMPLATE_ID: z.string().default('mock-template'),
  MOCK_OTP_ENABLED: z.string().transform((v) => v === 'true').default('true'),
  RAZORPAY_KEY_ID: z.string().default('mock-key'),
  RAZORPAY_KEY_SECRET: z.string().default('mock-secret'),
  RAZORPAY_WEBHOOK_SECRET: z.string().default('mock-webhook-secret'),
  R2_ACCESS_KEY: z.string().default('mock-key'),
  R2_SECRET_KEY: z.string().default('mock-secret'),
  R2_BUCKET: z.string().default('platform-files'),
  R2_ENDPOINT: z.string().default('https://account.r2.cloudflarestorage.com'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  OPENWEATHER_API_KEY: z.string().default('mock-key'),
  PORT: z.string().transform(Number).default('3000'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
});

export type Env = z.infer<typeof envSchema>;

let _env: Env | null = null;

export function getEnv(): Env {
  if (!_env) {
    const result = envSchema.safeParse(process.env);
    if (!result.success) {
      console.error('Invalid environment variables:', result.error.flatten().fieldErrors);
      process.exit(1);
    }
    _env = result.data;
  }
  return _env;
}
