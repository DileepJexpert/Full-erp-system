import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

interface CreateDiscountRuleInput {
  name: string;
  type: 'PERCENTAGE_OFF' | 'FLAT_OFF' | 'BUY_X_GET_Y' | 'MIN_CART_VALUE' | 'MEMBER_TIER' | 'FLASH_SALE';
  value: number;
  minCartValue?: number;
  maxDiscount?: number;
  buyQty?: number;
  getQty?: number;
  applicableItems?: string[];
  applicableCats?: string[];
  startDate?: string;
  endDate?: string;
  maxUsage?: number;
  locationId?: string;
}

interface UpdateDiscountRuleInput {
  name?: string;
  type?: 'PERCENTAGE_OFF' | 'FLAT_OFF' | 'BUY_X_GET_Y' | 'MIN_CART_VALUE' | 'MEMBER_TIER' | 'FLASH_SALE';
  value?: number;
  minCartValue?: number | null;
  maxDiscount?: number | null;
  buyQty?: number | null;
  getQty?: number | null;
  applicableItems?: string[];
  applicableCats?: string[];
  startDate?: string | null;
  endDate?: string | null;
  isActive?: boolean;
  maxUsage?: number | null;
  locationId?: string | null;
}

interface CreateCouponInput {
  code: string;
  discountRuleId: string;
  maxRedemptions?: number;
  expiresAt?: string;
}

interface CartItem {
  itemId: string;
  quantity: number;
  unitPrice: number;
  category?: string;
}

export async function createDiscountRule(businessId: string, data: CreateDiscountRuleInput) {
  return prisma.discountRule.create({
    data: {
      name: data.name,
      type: data.type,
      value: data.value,
      minCartValue: data.minCartValue,
      maxDiscount: data.maxDiscount,
      buyQty: data.buyQty,
      getQty: data.getQty,
      applicableItems: data.applicableItems ?? [],
      applicableCats: data.applicableCats ?? [],
      startDate: data.startDate ? new Date(data.startDate) : null,
      endDate: data.endDate ? new Date(data.endDate) : null,
      maxUsage: data.maxUsage,
      locationId: data.locationId,
      businessId,
    },
  });
}

export async function updateDiscountRule(businessId: string, id: string, data: UpdateDiscountRuleInput) {
  const rule = await prisma.discountRule.findFirst({
    where: { id, businessId },
  });

  if (!rule) {
    throw new NotFoundError('DiscountRule', id);
  }

  return prisma.discountRule.update({
    where: { id },
    data: {
      ...(data.name !== undefined && { name: data.name }),
      ...(data.type !== undefined && { type: data.type }),
      ...(data.value !== undefined && { value: data.value }),
      ...(data.minCartValue !== undefined && { minCartValue: data.minCartValue }),
      ...(data.maxDiscount !== undefined && { maxDiscount: data.maxDiscount }),
      ...(data.buyQty !== undefined && { buyQty: data.buyQty }),
      ...(data.getQty !== undefined && { getQty: data.getQty }),
      ...(data.applicableItems !== undefined && { applicableItems: data.applicableItems }),
      ...(data.applicableCats !== undefined && { applicableCats: data.applicableCats }),
      ...(data.startDate !== undefined && { startDate: data.startDate ? new Date(data.startDate) : null }),
      ...(data.endDate !== undefined && { endDate: data.endDate ? new Date(data.endDate) : null }),
      ...(data.isActive !== undefined && { isActive: data.isActive }),
      ...(data.maxUsage !== undefined && { maxUsage: data.maxUsage }),
      ...(data.locationId !== undefined && { locationId: data.locationId }),
    },
  });
}

export async function getDiscountRules(businessId: string) {
  return prisma.discountRule.findMany({
    where: { businessId, isActive: true },
    orderBy: { createdAt: 'desc' },
  });
}

export async function deleteDiscountRule(businessId: string, id: string) {
  const rule = await prisma.discountRule.findFirst({
    where: { id, businessId },
  });

  if (!rule) {
    throw new NotFoundError('DiscountRule', id);
  }

  return prisma.discountRule.update({
    where: { id },
    data: { isActive: false },
  });
}

export async function createCoupon(businessId: string, data: CreateCouponInput) {
  const rule = await prisma.discountRule.findFirst({
    where: { id: data.discountRuleId, businessId, isActive: true },
  });

  if (!rule) {
    throw new NotFoundError('DiscountRule', data.discountRuleId);
  }

  const existingCoupon = await prisma.coupon.findUnique({
    where: { code_businessId: { code: data.code.toUpperCase(), businessId } },
  });

  if (existingCoupon) {
    throw new BadRequestError(`Coupon code '${data.code}' already exists`);
  }

  return prisma.coupon.create({
    data: {
      code: data.code.toUpperCase(),
      discountRuleId: data.discountRuleId,
      maxRedemptions: data.maxRedemptions,
      expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
      businessId,
    },
  });
}

export async function validateCoupon(businessId: string, code: string) {
  const coupon = await prisma.coupon.findUnique({
    where: { code_businessId: { code: code.toUpperCase(), businessId } },
  });

  if (!coupon) {
    return { valid: false, reason: 'Coupon not found' };
  }

  if (!coupon.isActive) {
    return { valid: false, reason: 'Coupon is inactive' };
  }

  if (coupon.expiresAt && coupon.expiresAt < new Date()) {
    return { valid: false, reason: 'Coupon has expired' };
  }

  if (coupon.maxRedemptions && coupon.timesRedeemed >= coupon.maxRedemptions) {
    return { valid: false, reason: 'Coupon has reached maximum redemptions' };
  }

  const rule = await prisma.discountRule.findFirst({
    where: { id: coupon.discountRuleId, isActive: true },
  });

  if (!rule) {
    return { valid: false, reason: 'Associated discount rule is inactive' };
  }

  return { valid: true, coupon, discountRule: rule };
}

export async function redeemCoupon(businessId: string, code: string) {
  const coupon = await prisma.coupon.findUnique({
    where: { code_businessId: { code: code.toUpperCase(), businessId } },
  });

  if (!coupon) {
    throw new NotFoundError('Coupon', code);
  }

  if (!coupon.isActive) {
    throw new BadRequestError('Coupon is inactive');
  }

  if (coupon.expiresAt && coupon.expiresAt < new Date()) {
    throw new BadRequestError('Coupon has expired');
  }

  if (coupon.maxRedemptions && coupon.timesRedeemed >= coupon.maxRedemptions) {
    throw new BadRequestError('Coupon has reached maximum redemptions');
  }

  return prisma.coupon.update({
    where: { id: coupon.id },
    data: { timesRedeemed: { increment: 1 } },
  });
}

export async function calculateDiscount(
  businessId: string,
  cartItems: CartItem[],
  couponCode?: string,
) {
  const now = new Date();
  const cartTotal = cartItems.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  const cartItemIds = cartItems.map((i) => i.itemId);
  const cartCategories = cartItems.map((i) => i.category).filter(Boolean) as string[];

  // Fetch active rules for this business
  const rules = await prisma.discountRule.findMany({
    where: {
      businessId,
      isActive: true,
      OR: [{ startDate: null }, { startDate: { lte: now } }],
    },
  });

  // Filter rules that haven't ended and haven't exceeded max usage
  const activeRules = rules.filter((rule) => {
    if (rule.endDate && rule.endDate < now) return false;
    if (rule.maxUsage && rule.timesUsed >= rule.maxUsage) return false;
    return true;
  });

  let couponDiscount = 0;
  let couponRuleName: string | null = null;

  // Apply coupon-based discount
  if (couponCode) {
    const validation = await validateCoupon(businessId, couponCode);
    if (validation.valid && validation.discountRule) {
      const rule = validation.discountRule;
      couponDiscount = computeRuleDiscount(rule, cartItems, cartTotal);
      couponRuleName = rule.name;
    }
  }

  // Apply automatic rules (non-coupon)
  let autoDiscount = 0;
  const appliedRules: Array<{ ruleId: string; name: string; discount: number }> = [];

  for (const rule of activeRules) {
    // Check if rule is applicable to cart items
    const isApplicable = isRuleApplicable(rule, cartItemIds, cartCategories);
    if (!isApplicable) continue;

    const discount = computeRuleDiscount(rule, cartItems, cartTotal);
    if (discount > 0) {
      autoDiscount += discount;
      appliedRules.push({ ruleId: rule.id, name: rule.name, discount });
    }
  }

  // Use the best discount: either coupon or auto rules
  const totalDiscount = Math.max(couponDiscount, autoDiscount);
  const breakdown = couponDiscount >= autoDiscount && couponCode
    ? [{ source: 'coupon', code: couponCode, name: couponRuleName, discount: couponDiscount }]
    : appliedRules.map((r) => ({ source: 'auto', ruleId: r.ruleId, name: r.name, discount: r.discount }));

  return {
    cartTotal,
    totalDiscount: Math.round(totalDiscount * 100) / 100,
    finalTotal: Math.round((cartTotal - totalDiscount) * 100) / 100,
    breakdown,
  };
}

function isRuleApplicable(
  rule: { applicableItems: string[]; applicableCats: string[] },
  cartItemIds: string[],
  cartCategories: string[],
): boolean {
  // If no restrictions, rule applies to all
  if (rule.applicableItems.length === 0 && rule.applicableCats.length === 0) {
    return true;
  }

  if (rule.applicableItems.length > 0) {
    const hasMatchingItem = cartItemIds.some((id) => rule.applicableItems.includes(id));
    if (hasMatchingItem) return true;
  }

  if (rule.applicableCats.length > 0) {
    const hasMatchingCat = cartCategories.some((cat) => rule.applicableCats.includes(cat));
    if (hasMatchingCat) return true;
  }

  return false;
}

function computeRuleDiscount(
  rule: {
    type: string;
    value: number;
    minCartValue: number | null;
    maxDiscount: number | null;
    buyQty: number | null;
    getQty: number | null;
  },
  cartItems: CartItem[],
  cartTotal: number,
): number {
  let discount = 0;

  switch (rule.type) {
    case 'PERCENTAGE_OFF': {
      discount = cartTotal * (rule.value / 100);
      break;
    }
    case 'FLAT_OFF': {
      discount = rule.value;
      break;
    }
    case 'MIN_CART_VALUE': {
      if (rule.minCartValue && cartTotal >= rule.minCartValue) {
        discount = rule.value;
      }
      break;
    }
    case 'BUY_X_GET_Y': {
      if (rule.buyQty && rule.getQty) {
        const totalQty = cartItems.reduce((sum, item) => sum + item.quantity, 0);
        const sets = Math.floor(totalQty / (rule.buyQty + rule.getQty));
        // Free items valued at cheapest item price
        const sortedPrices = cartItems
          .map((i) => i.unitPrice)
          .sort((a, b) => a - b);
        const cheapestPrice = sortedPrices[0] ?? 0;
        discount = sets * rule.getQty * cheapestPrice;
      }
      break;
    }
    case 'FLASH_SALE': {
      discount = cartTotal * (rule.value / 100);
      break;
    }
    case 'MEMBER_TIER': {
      discount = cartTotal * (rule.value / 100);
      break;
    }
  }

  // Apply max discount cap
  if (rule.maxDiscount && discount > rule.maxDiscount) {
    discount = rule.maxDiscount;
  }

  // Discount cannot exceed cart total
  if (discount > cartTotal) {
    discount = cartTotal;
  }

  return Math.round(discount * 100) / 100;
}
