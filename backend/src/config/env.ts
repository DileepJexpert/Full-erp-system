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
  // V3: WhatsApp (Gupshup BSP)
  GUPSHUP_API_KEY: z.string().default('mock-key'),
  GUPSHUP_APP_NAME: z.string().default('erp-bot'),
  GUPSHUP_SOURCE_NUMBER: z.string().default('917000000000'),
  GUPSHUP_WEBHOOK_SECRET: z.string().default('mock-webhook-secret'),
  // V3: Claude API (Anthropic)
  ANTHROPIC_API_KEY: z.string().default('mock-key'),
  CLAUDE_MODEL_FAST: z.string().default('claude-haiku-4-5-20251001'),
  CLAUDE_MODEL_SMART: z.string().default('claude-sonnet-4-6'),
  // V3: Marketplace
  MARKETPLACE_COMMISSION_PCT: z.string().transform(Number).default('3'),
  // V3: Email (scheduled reports)
  SMTP_HOST: z.string().default('smtp.gmail.com'),
  SMTP_PORT: z.string().transform(Number).default('587'),
  SMTP_USER: z.string().default(''),
  SMTP_PASS: z.string().default(''),
  REPORT_SENDER_EMAIL: z.string().default('reports@yourdomain.com'),
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
