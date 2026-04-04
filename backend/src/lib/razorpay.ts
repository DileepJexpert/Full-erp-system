import { getEnv } from '../config/env.js';
import crypto from 'node:crypto';

interface RazorpayQrResponse {
  id: string;
  image_url: string;
  qr_code_url: string;
}

interface RazorpayOrderResponse {
  id: string;
  amount: number;
  currency: string;
  status: string;
}

function getAuthHeader(): string {
  const env = getEnv();
  return Buffer.from(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`).toString('base64');
}

export async function createQrCode(
  amount: number,
  description: string,
  customerName?: string,
): Promise<RazorpayQrResponse> {
  const response = await fetch('https://api.razorpay.com/v1/payments/qr_codes', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${getAuthHeader()}`,
    },
    body: JSON.stringify({
      type: 'upi_qr',
      name: customerName ?? 'Customer',
      usage: 'single_use',
      fixed_amount: true,
      payment_amount: Math.round(amount * 100), // paise
      description,
      close_by: Math.floor(Date.now() / 1000) + 1800, // 30 min expiry
    }),
  });

  if (!response.ok) {
    throw new Error(`Razorpay QR creation failed: ${response.statusText}`);
  }

  return response.json() as Promise<RazorpayQrResponse>;
}

export async function createOrder(
  amount: number,
  receiptId: string,
): Promise<RazorpayOrderResponse> {
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${getAuthHeader()}`,
    },
    body: JSON.stringify({
      amount: Math.round(amount * 100),
      currency: 'INR',
      receipt: receiptId,
    }),
  });

  if (!response.ok) {
    throw new Error(`Razorpay order creation failed: ${response.statusText}`);
  }

  return response.json() as Promise<RazorpayOrderResponse>;
}

export function verifyWebhookSignature(body: string, signature: string): boolean {
  const env = getEnv();
  const expectedSignature = crypto
    .createHmac('sha256', env.RAZORPAY_WEBHOOK_SECRET)
    .update(body)
    .digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature),
  );
}
