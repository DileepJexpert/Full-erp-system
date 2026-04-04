import { getEnv } from '../config/env.js';
import { MOCK_OTP } from '../config/constants.js';

export async function sendOtp(phone: string): Promise<{ success: boolean; requestId?: string }> {
  const env = getEnv();

  if (env.MOCK_OTP_ENABLED) {
    console.log(`[MOCK OTP] Sending OTP ${MOCK_OTP} to ${phone}`);
    return { success: true, requestId: 'mock-request-id' };
  }

  const response = await fetch('https://control.msg91.com/api/v5/otp', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      authkey: env.MSG91_AUTH_KEY,
    },
    body: JSON.stringify({
      template_id: env.MSG91_TEMPLATE_ID,
      mobile: `91${phone}`,
      otp_length: 6,
    }),
  });

  const data = await response.json() as { type: string; request_id?: string };
  return {
    success: data.type === 'success',
    requestId: data.request_id,
  };
}

export async function verifyOtp(phone: string, otp: string): Promise<boolean> {
  const env = getEnv();

  if (env.MOCK_OTP_ENABLED) {
    return otp === MOCK_OTP;
  }

  const response = await fetch(
    `https://control.msg91.com/api/v5/otp/verify?mobile=91${phone}&otp=${otp}`,
    {
      method: 'GET',
      headers: { authkey: env.MSG91_AUTH_KEY },
    },
  );

  const data = await response.json() as { type: string };
  return data.type === 'success';
}

export async function sendWhatsApp(phone: string, templateName: string, params: Record<string, string>): Promise<boolean> {
  const env = getEnv();

  if (env.MOCK_OTP_ENABLED) {
    console.log(`[MOCK WhatsApp] Sending ${templateName} to ${phone}`, params);
    return true;
  }

  const response = await fetch('https://control.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      authkey: env.MSG91_AUTH_KEY,
    },
    body: JSON.stringify({
      integrated_number: '91XXXXXXXXXX',
      content_type: 'template',
      payload: {
        to: `91${phone}`,
        type: 'template',
        template: {
          name: templateName,
          language: { code: 'en', policy: 'deterministic' },
          components: Object.entries(params).map(([, value]) => ({
            type: 'body',
            parameters: [{ type: 'text', text: value }],
          })),
        },
      },
    }),
  });

  return response.ok;
}
