import { getEnv } from '../config/env.js';

const GUPSHUP_API_URL = 'https://api.gupshup.io/wa/api/v1/msg';

interface GupshupResponse {
  status: string;
  messageId?: string;
  message?: string;
}

export class GupshupClient {
  private apiKey: string;
  private appName: string;
  private sourceNumber: string;

  constructor() {
    const env = getEnv();
    this.apiKey = env.GUPSHUP_API_KEY;
    this.appName = env.GUPSHUP_APP_NAME;
    this.sourceNumber = env.GUPSHUP_SOURCE_NUMBER;
  }

  private async send(destination: string, message: object): Promise<GupshupResponse> {
    const body = new URLSearchParams({
      channel: 'whatsapp',
      source: this.sourceNumber,
      destination: destination.replace(/^\+/, ''),
      'src.name': this.appName,
      message: JSON.stringify(message),
    });

    const response = await fetch(GUPSHUP_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        apikey: this.apiKey,
      },
      body: body.toString(),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Gupshup API error ${response.status}: ${text}`);
    }

    return response.json() as Promise<GupshupResponse>;
  }

  async sendText(phone: string, message: string): Promise<void> {
    await this.send(phone, {
      type: 'text',
      text: message,
    });
  }

  async sendTemplate(
    phone: string,
    templateId: string,
    params: Record<string, string>,
  ): Promise<void> {
    const paramArray = Object.entries(params).map(([key, value]) => ({
      [key]: value,
    }));

    await this.send(phone, {
      isHSM: 'true',
      type: 'text',
      id: templateId,
      params: paramArray,
    });
  }

  async sendImage(phone: string, imageUrl: string, caption?: string): Promise<void> {
    await this.send(phone, {
      type: 'image',
      originalUrl: imageUrl,
      previewUrl: imageUrl,
      caption: caption ?? '',
    });
  }

  async sendInteractive(
    phone: string,
    body: string,
    buttons: Array<{ id: string; title: string }>,
  ): Promise<void> {
    await this.send(phone, {
      type: 'quick_reply',
      content: {
        type: 'text',
        text: body,
      },
      options: buttons.map((b) => ({
        type: 'text',
        title: b.title,
        postbackText: b.id,
      })),
    });
  }
}

export const gupshup = new GupshupClient();
