import Anthropic from '@anthropic-ai/sdk';
import { getEnv } from '../config/env.js';

class ClaudeClient {
  private client: Anthropic;

  constructor() {
    this.client = new Anthropic({ apiKey: getEnv().ANTHROPIC_API_KEY });
  }

  /**
   * Simple single-turn query to Claude.
   */
  async query(
    prompt: string,
    options?: {
      model?: string;
      maxTokens?: number;
      system?: string;
    },
  ): Promise<{ text: string; tokensUsed: number }> {
    const model = options?.model ?? getEnv().CLAUDE_MODEL_FAST;

    const response = await this.client.messages.create({
      model,
      max_tokens: options?.maxTokens ?? 1024,
      system: options?.system,
      messages: [{ role: 'user', content: prompt }],
    });

    const text =
      response.content[0].type === 'text' ? response.content[0].text : '';
    const tokensUsed =
      (response.usage?.input_tokens ?? 0) +
      (response.usage?.output_tokens ?? 0);

    return { text, tokensUsed };
  }

  /**
   * Multi-turn query with tool-use support.
   */
  async queryWithTools(
    messages: Anthropic.MessageParam[],
    tools: Anthropic.Tool[],
    system?: string,
  ): Promise<Anthropic.Message> {
    return this.client.messages.create({
      model: getEnv().CLAUDE_MODEL_SMART,
      max_tokens: 4096,
      system,
      messages,
      tools,
    });
  }
}

export const claude = new ClaudeClient();
