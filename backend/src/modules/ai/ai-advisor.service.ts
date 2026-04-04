import type Anthropic from '@anthropic-ai/sdk';
import { prisma } from '../../lib/prisma.js';
import { claude } from '../../lib/claude.js';
import { AI_TOOLS, executeTool } from './ai-tools.js';

interface AdvisorResult {
  answer: string;
  tokensUsed: number;
  latencyMs: number;
  toolsUsed: string[];
}

/**
 * Build the system prompt for the AI advisor, tailored to the business.
 */
async function buildSystemPrompt(businessId: string): Promise<string> {
  // Fetch business context
  const [business, locationCount] = await Promise.all([
    prisma.business.findUnique({
      where: { id: businessId },
      select: { name: true, type: true },
    }),
    prisma.location.count({ where: { businessId } }),
  ]);

  const businessType = (business as any)?.type ?? 'food';
  const businessName = business?.name ?? 'your business';

  return (
    `You are a business advisor for "${businessName}", a ${businessType} business with ${locationCount} location(s) in India. ` +
    `Speak in simple Hindi-English mix (Hinglish). Give specific, actionable advice with numbers.\n\n` +
    `Guidelines:\n` +
    `- Always reference actual data from tools before giving advice\n` +
    `- Use Rs (rupees) for currency, Indian number formatting (lakhs/crores)\n` +
    `- Keep responses concise (under 500 words)\n` +
    `- Suggest 2-3 specific action items when possible\n` +
    `- If data is insufficient, say so honestly\n` +
    `- Today's date: ${new Date().toISOString().split('T')[0]}`
  );
}

/**
 * Execute a RAG-style advisory query:
 * 1. Send question + tools to Claude
 * 2. Execute any tool calls
 * 3. Send tool results back to Claude for final answer
 * 4. Log to AIQueryLog
 */
export async function askAdvisor(
  businessId: string,
  userId: string,
  question: string,
): Promise<AdvisorResult> {
  const startTime = Date.now();
  let totalTokens = 0;
  const toolsUsed: string[] = [];

  const systemPrompt = await buildSystemPrompt(businessId);

  const messages: Anthropic.MessageParam[] = [
    { role: 'user', content: question },
  ];

  // First call: Claude decides which tools to call
  let response = await claude.queryWithTools(messages, AI_TOOLS, systemPrompt);
  totalTokens +=
    (response.usage?.input_tokens ?? 0) + (response.usage?.output_tokens ?? 0);

  // Tool-use loop (max 5 iterations to prevent infinite loops)
  let iterations = 0;
  const maxIterations = 5;

  while (response.stop_reason === 'tool_use' && iterations < maxIterations) {
    iterations++;

    const toolUseBlocks = response.content.filter(
      (block): block is Anthropic.ContentBlock & { type: 'tool_use' } =>
        block.type === 'tool_use',
    );

    if (toolUseBlocks.length === 0) break;

    // Execute all tool calls
    const toolResults: Anthropic.ToolResultBlockParam[] = [];

    for (const toolBlock of toolUseBlocks) {
      toolsUsed.push(toolBlock.name);

      try {
        const result = await executeTool(
          toolBlock.name,
          toolBlock.input as Record<string, unknown>,
          businessId,
        );
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolBlock.id,
          content: JSON.stringify(result),
        });
      } catch (error) {
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolBlock.id,
          content: JSON.stringify({
            error: error instanceof Error ? error.message : 'Tool execution failed',
          }),
          is_error: true,
        });
      }
    }

    // Send tool results back to Claude
    messages.push({ role: 'assistant', content: response.content });
    messages.push({ role: 'user', content: toolResults });

    response = await claude.queryWithTools(messages, AI_TOOLS, systemPrompt);
    totalTokens +=
      (response.usage?.input_tokens ?? 0) +
      (response.usage?.output_tokens ?? 0);
  }

  // Extract final text response
  const textBlock = response.content.find(
    (block): block is Anthropic.TextBlock => block.type === 'text',
  );
  const answer = textBlock?.text ?? 'Sorry, I could not generate a response.';

  const latencyMs = Date.now() - startTime;

  // Log to AIQueryLog
  await prisma.aIQueryLog.create({
    data: {
      type: 'BUSINESS_ADVICE',
      query: question,
      context: { toolsUsed },
      response: answer,
      model: response.model,
      tokensUsed: totalTokens,
      latencyMs,
      userId,
      businessId,
    },
  });

  return {
    answer,
    tokensUsed: totalTokens,
    latencyMs,
    toolsUsed,
  };
}
