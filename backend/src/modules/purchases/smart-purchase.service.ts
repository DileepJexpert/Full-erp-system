import { prisma } from '../../lib/prisma.js';
import { eventBus, EVENTS } from '../../lib/event-bus.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

interface SmartPurchaseInput {
  supplierId: string;
  date: string;
  items: Array<{ itemId: string; quantity: number; unitPrice: number }>;
  notes?: string;
  entryMethod: string;
  billPhotoUrl?: string;
  billPhotoKey?: string;
  aiExtractedRaw?: any;
  aiConfidence?: number;
  voiceTranscript?: string;
  locationId?: string;
}

export async function savePurchaseWithSmartFeatures(
  businessId: string,
  userId: string,
  userRole: string,
  input: SmartPurchaseInput,
): Promise<{ purchase: any; suggestTemplate: boolean }> {
  // 1. Calculate totalAmount
  const totalAmount = input.items.reduce(
    (sum, i) => sum + i.quantity * i.unitPrice,
    0,
  );

  // 2. Fetch business settings
  const business = await prisma.business.findUnique({
    where: { id: businessId },
    select: { purchaseApprovalThreshold: true },
  });
  if (!business) throw new NotFoundError('Business', businessId);

  const threshold = business.purchaseApprovalThreshold;

  // 3. Determine approvalStatus
  let approvalStatus: string;
  if (threshold === 0 || totalAmount <= threshold || userRole === 'OWNER') {
    approvalStatus = 'AUTO_APPROVED';
  } else {
    approvalStatus = 'PENDING_APPROVAL';
  }

  // Verify supplier exists
  const supplier = await prisma.supplier.findFirst({
    where: { id: input.supplierId, businessId, isActive: true },
  });
  if (!supplier) throw new NotFoundError('Supplier', input.supplierId);

  // Verify all items exist
  const itemIds = input.items.map((i) => i.itemId);
  const existingItems = await prisma.item.findMany({
    where: { id: { in: itemIds }, businessId },
  });
  if (existingItems.length !== itemIds.length) {
    throw new BadRequestError('One or more items not found');
  }

  // Build a map of existing items for price calculations
  const itemMap = new Map(existingItems.map((item) => [item.id, item]));

  // 4. Create purchase in transaction
  const purchase = await prisma.$transaction(async (tx) => {
    const newPurchase = await tx.purchase.create({
      data: {
        businessId,
        supplierId: input.supplierId,
        createdById: userId,
        date: new Date(input.date),
        totalAmount,
        amountPaid: 0,
        paymentStatus: 'PENDING',
        notes: input.notes,
        entryMethod: input.entryMethod,
        billPhotoUrl: input.billPhotoUrl,
        billPhotoKey: input.billPhotoKey,
        aiExtractedRaw: input.aiExtractedRaw ?? undefined,
        aiConfidence: input.aiConfidence,
        voiceTranscript: input.voiceTranscript,
        approvalStatus,
        locationId: input.locationId,
        items: {
          create: input.items.map((i) => ({
            itemId: i.itemId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            lineTotal: i.quantity * i.unitPrice,
          })),
        },
      },
      include: {
        items: { include: { item: true } },
        supplier: { select: { id: true, name: true } },
      },
    });

    // If AUTO_APPROVED: update stock and prices immediately
    if (approvalStatus === 'AUTO_APPROVED') {
      for (const lineItem of input.items) {
        const existing = itemMap.get(lineItem.itemId);

        // Update centralStock
        await tx.item.update({
          where: { id: lineItem.itemId },
          data: {
            centralStock: { increment: lineItem.quantity },
            lastPurchasePrice: lineItem.unitPrice,
            avgPurchasePrice:
              existing?.avgPurchasePrice != null
                ? existing.avgPurchasePrice * 0.8 + lineItem.unitPrice * 0.2
                : lineItem.unitPrice,
            preferredSupplierId: input.supplierId,
          },
        });
      }
    } else {
      // PENDING_APPROVAL: still update price info but NOT stock
      for (const lineItem of input.items) {
        const existing = itemMap.get(lineItem.itemId);
        await tx.item.update({
          where: { id: lineItem.itemId },
          data: {
            lastPurchasePrice: lineItem.unitPrice,
            avgPurchasePrice:
              existing?.avgPurchasePrice != null
                ? existing.avgPurchasePrice * 0.8 + lineItem.unitPrice * 0.2
                : lineItem.unitPrice,
            preferredSupplierId: input.supplierId,
          },
        });
      }
    }

    return newPurchase;
  });

  eventBus.emit(EVENTS.PURCHASE_CREATED, { purchaseId: purchase.id, businessId });

  // 5. Check template suggestion
  const ninetyDaysAgo = new Date();
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

  const [recentCount, existingTemplate] = await Promise.all([
    prisma.purchase.count({
      where: {
        businessId,
        supplierId: input.supplierId,
        createdAt: { gte: ninetyDaysAgo },
      },
    }),
    prisma.purchaseTemplate.findFirst({
      where: {
        businessId,
        supplierId: input.supplierId,
      },
    }),
  ]);

  const suggestTemplate = recentCount >= 3 && !existingTemplate;

  return { purchase, suggestTemplate };
}
