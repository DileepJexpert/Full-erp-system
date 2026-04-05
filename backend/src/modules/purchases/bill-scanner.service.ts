import Anthropic from '@anthropic-ai/sdk';
import { getEnv } from '../../config/env.js';
import { prisma } from '../../lib/prisma.js';
import { claude } from '../../lib/claude.js';
import { fuzzyMatchItem } from './fuzzy-matcher.js';
import type { MatchResult } from './fuzzy-matcher.js';

export interface ExtractedItem {
  rawText: string;
  matchedItemId: string | null;
  matchedItemName: string | null;
  quantity: number;
  unit: string;
  unitPrice: number;
  lineTotal: number;
  confidence: number;
}

export interface ExtractedBill {
  supplier: { name: string | null; phone: string | null; matchedId: string | null };
  items: ExtractedItem[];
  grandTotal: number;
  billDate: string | null;
  billNumber: string | null;
  confidence: number;
}

interface RawClaudeItem {
  name: string;
  quantity: number;
  unit: string;
  unitPrice: number;
  lineTotal: number;
}

interface RawClaudeExtraction {
  supplier?: { name?: string; phone?: string };
  items: RawClaudeItem[];
  grandTotal: number;
  billDate?: string;
  billNumber?: string;
}

// ──────────────────────────────────────────────
// Internal helpers
// ──────────────────────────────────────────────

async function loadBusinessData(businessId: string) {
  const [items, suppliers, globalAliases] = await Promise.all([
    prisma.item.findMany({
      where: { businessId, isActive: true },
      select: { id: true, name: true, aliases: true, unit: true, costPrice: true },
    }),
    prisma.supplier.findMany({
      where: { businessId, isActive: true },
      select: { id: true, name: true, phone: true },
    }),
    prisma.itemAliasGlobal.findMany(),
  ]);
  return { items, suppliers, globalAliases };
}

function buildItemList(
  items: Array<{ id: string; name: string; aliases: string[]; unit: string; costPrice: number }>,
): string {
  return items
    .map((i) => `- ${i.name} (unit: ${i.unit}, aliases: ${i.aliases.join(', ') || 'none'})`)
    .join('\n');
}

function buildSupplierList(
  suppliers: Array<{ id: string; name: string; phone: string | null }>,
): string {
  return suppliers
    .map((s) => `- ${s.name}${s.phone ? ` (${s.phone})` : ''}`)
    .join('\n');
}

function buildExtractionPrompt(itemList: string, supplierList: string): string {
  return `You are an expert at reading purchase bills / invoices from Indian businesses.

Extract all items, supplier info, and totals from the bill. Many items may be written in Hindi/Hinglish.

KNOWN INVENTORY ITEMS (match to these when possible):
${itemList}

KNOWN SUPPLIERS:
${supplierList}

COMMON HINDI ITEM NAMES:
pyaaz=Onion, aloo=Potato, tamatar=Tomato, gobhi=Cauliflower, palak=Spinach,
haldi=Turmeric, mirch=Chilli, jeera=Cumin, dhaniya=Coriander, rai=Mustard Seeds,
atta=Wheat Flour, maida=Refined Flour, chawal=Rice, dal=Lentils, cheeni=Sugar,
doodh=Milk, paneer=Cottage Cheese, dahi=Yogurt, ghee=Clarified Butter,
anda=Egg, chai patti=Tea Leaves

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{
  "supplier": { "name": "supplier name or null", "phone": "phone or null" },
  "items": [
    { "name": "item name as written", "quantity": 0, "unit": "kg/pcs/ltr/etc", "unitPrice": 0, "lineTotal": 0 }
  ],
  "grandTotal": 0,
  "billDate": "YYYY-MM-DD or null",
  "billNumber": "bill number or null"
}`;
}

function matchSupplier(
  rawName: string | null | undefined,
  rawPhone: string | null | undefined,
  suppliers: Array<{ id: string; name: string; phone: string | null }>,
): string | null {
  if (!rawName && !rawPhone) return null;

  // Try phone match first (most reliable)
  if (rawPhone) {
    const cleanPhone = rawPhone.replace(/\D/g, '').slice(-10);
    const phoneMatch = suppliers.find(
      (s) => s.phone && s.phone.replace(/\D/g, '').slice(-10) === cleanPhone,
    );
    if (phoneMatch) return phoneMatch.id;
  }

  // Try name match
  if (rawName) {
    const normalizedName = rawName.trim().toLowerCase();
    const exactMatch = suppliers.find(
      (s) => s.name.toLowerCase() === normalizedName,
    );
    if (exactMatch) return exactMatch.id;

    // Partial name match
    const partialMatch = suppliers.find(
      (s) =>
        s.name.toLowerCase().includes(normalizedName) ||
        normalizedName.includes(s.name.toLowerCase()),
    );
    if (partialMatch) return partialMatch.id;
  }

  return null;
}

async function postProcessItems(
  rawItems: RawClaudeItem[],
  inventoryItems: Array<{ id: string; name: string; aliases: string[]; unit: string; costPrice: number }>,
  globalAliases: Array<{ alias: string; canonical: string; category: string }>,
): Promise<ExtractedItem[]> {
  const results: ExtractedItem[] = [];

  for (const raw of rawItems) {
    const match: MatchResult | null = await fuzzyMatchItem(
      raw.name,
      inventoryItems,
      globalAliases,
    );

    results.push({
      rawText: raw.name,
      matchedItemId: match?.itemId ?? null,
      matchedItemName: match?.itemName ?? null,
      quantity: raw.quantity,
      unit: raw.unit,
      unitPrice: raw.unitPrice,
      lineTotal: raw.lineTotal || raw.quantity * raw.unitPrice,
      confidence: match?.confidence ?? 0,
    });
  }

  return results;
}

function parseClaudeResponse(text: string): RawClaudeExtraction {
  // Strip markdown code fences if present
  let cleaned = text.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
  }
  return JSON.parse(cleaned) as RawClaudeExtraction;
}

function calculateOverallConfidence(items: ExtractedItem[]): number {
  if (items.length === 0) return 0;
  const totalConfidence = items.reduce((sum, item) => sum + item.confidence, 0);
  return Math.round((totalConfidence / items.length) * 100) / 100;
}

// ──────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────

/**
 * Scan a bill image using Claude Vision and extract structured data.
 */
export async function scanBill(
  imageBase64: string,
  businessId: string,
): Promise<ExtractedBill> {
  const { items, suppliers, globalAliases } = await loadBusinessData(businessId);
  const itemList = buildItemList(items);
  const supplierList = buildSupplierList(suppliers);
  const prompt = buildExtractionPrompt(itemList, supplierList);

  // Use raw Anthropic client for vision (image content blocks)
  const env = getEnv();
  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

  // Detect media type from base64 header or default to jpeg
  let mediaType: 'image/jpeg' | 'image/png' | 'image/gif' | 'image/webp' = 'image/jpeg';
  let cleanBase64 = imageBase64;
  if (imageBase64.startsWith('data:')) {
    const match = imageBase64.match(/^data:(image\/\w+);base64,/);
    if (match) {
      mediaType = match[1] as typeof mediaType;
      cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');
    }
  }

  const response = await anthropic.messages.create({
    model: env.CLAUDE_MODEL_SMART,
    max_tokens: 4096,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mediaType,
              data: cleanBase64,
            },
          },
          {
            type: 'text',
            text: `${prompt}\n\nExtract all information from this bill image.`,
          },
        ],
      },
    ],
  });

  const responseText =
    response.content[0].type === 'text' ? response.content[0].text : '';
  const extracted = parseClaudeResponse(responseText);

  const processedItems = await postProcessItems(
    extracted.items,
    items,
    globalAliases,
  );

  const matchedSupplierId = matchSupplier(
    extracted.supplier?.name,
    extracted.supplier?.phone,
    suppliers,
  );

  return {
    supplier: {
      name: extracted.supplier?.name ?? null,
      phone: extracted.supplier?.phone ?? null,
      matchedId: matchedSupplierId,
    },
    items: processedItems,
    grandTotal: extracted.grandTotal,
    billDate: extracted.billDate ?? null,
    billNumber: extracted.billNumber ?? null,
    confidence: calculateOverallConfidence(processedItems),
  };
}

/**
 * Parse a text-based bill (e.g. pasted or OCR'd text) using Claude Haiku.
 */
export async function parseTextBill(
  text: string,
  businessId: string,
): Promise<ExtractedBill> {
  const { items, suppliers, globalAliases } = await loadBusinessData(businessId);
  const itemList = buildItemList(items);
  const supplierList = buildSupplierList(suppliers);
  const prompt = buildExtractionPrompt(itemList, supplierList);

  const env = getEnv();
  const { text: responseText } = await claude.query(
    `${prompt}\n\nHere is the bill text:\n\n${text}`,
    { model: env.CLAUDE_MODEL_FAST, maxTokens: 4096 },
  );

  const extracted = parseClaudeResponse(responseText);

  const processedItems = await postProcessItems(
    extracted.items,
    items,
    globalAliases,
  );

  const matchedSupplierId = matchSupplier(
    extracted.supplier?.name,
    extracted.supplier?.phone,
    suppliers,
  );

  return {
    supplier: {
      name: extracted.supplier?.name ?? null,
      phone: extracted.supplier?.phone ?? null,
      matchedId: matchedSupplierId,
    },
    items: processedItems,
    grandTotal: extracted.grandTotal,
    billDate: extracted.billDate ?? null,
    billNumber: extracted.billNumber ?? null,
    confidence: calculateOverallConfidence(processedItems),
  };
}

/**
 * Parse a voice transcript (e.g. from WhatsApp voice note) using Claude Haiku.
 */
export async function parseVoiceTranscript(
  transcript: string,
  businessId: string,
): Promise<ExtractedBill> {
  const { items, suppliers, globalAliases } = await loadBusinessData(businessId);
  const itemList = buildItemList(items);
  const supplierList = buildSupplierList(suppliers);

  const env = getEnv();
  const voicePrompt = `You are an expert at understanding spoken purchase descriptions from Indian business owners.
The speaker is describing items they purchased. They may speak in Hindi, Hinglish, or English.
Numbers may be spoken as words (e.g., "do sau" = 200, "paanch kilo" = 5 kg).

KNOWN INVENTORY ITEMS (match to these when possible):
${itemList}

KNOWN SUPPLIERS:
${supplierList}

COMMON HINDI ITEM NAMES:
pyaaz=Onion, aloo=Potato, tamatar=Tomato, gobhi=Cauliflower, palak=Spinach,
haldi=Turmeric, mirch=Chilli, jeera=Cumin, dhaniya=Coriander, rai=Mustard Seeds,
atta=Wheat Flour, maida=Refined Flour, chawal=Rice, dal=Lentils, cheeni=Sugar,
doodh=Milk, paneer=Cottage Cheese, dahi=Yogurt, ghee=Clarified Butter,
anda=Egg, chai patti=Tea Leaves

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{
  "supplier": { "name": "supplier name or null", "phone": "null" },
  "items": [
    { "name": "item name", "quantity": 0, "unit": "kg/pcs/ltr/etc", "unitPrice": 0, "lineTotal": 0 }
  ],
  "grandTotal": 0,
  "billDate": null,
  "billNumber": null
}`;

  const { text: responseText } = await claude.query(
    `${voicePrompt}\n\nVoice transcript:\n"${transcript}"`,
    { model: env.CLAUDE_MODEL_FAST, maxTokens: 4096 },
  );

  const extracted = parseClaudeResponse(responseText);

  const processedItems = await postProcessItems(
    extracted.items,
    items,
    globalAliases,
  );

  const matchedSupplierId = matchSupplier(
    extracted.supplier?.name,
    extracted.supplier?.phone,
    suppliers,
  );

  return {
    supplier: {
      name: extracted.supplier?.name ?? null,
      phone: extracted.supplier?.phone ?? null,
      matchedId: matchedSupplierId,
    },
    items: processedItems,
    grandTotal: extracted.grandTotal,
    billDate: extracted.billDate ?? null,
    billNumber: extracted.billNumber ?? null,
    confidence: calculateOverallConfidence(processedItems),
  };
}
