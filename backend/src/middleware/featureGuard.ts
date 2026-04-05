import type { FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../lib/prisma.js';
import { FeatureDisabledError } from '../utils/errors.js';

// All feature flag field names on the Business model
type FeatureFlag =
  | 'enableDispatch'
  | 'enableReconciliation'
  | 'enableWastageMargin'
  | 'enableBatchExpiry'
  | 'enableAppointments'
  | 'enableCreditLedger'
  | 'enableWeightBilling'
  | 'enableCommissions'
  | 'enableMemberships'
  | 'enableBarcode'
  | 'enableDelivery'
  | 'enableAggregators'
  | 'enableWeather'
  | 'enableAnomaly'
  | 'enablePerformance'
  | 'enableLoyalty';

/**
 * Fastify preHandler that checks if a feature flag is enabled for the business.
 * Usage: preHandler: [authenticate, requireFeature('enableDispatch')]
 */
export function requireFeature(flag: FeatureFlag) {
  return async (request: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    const businessId = request.tenant?.businessId;
    if (!businessId) {
      throw new FeatureDisabledError(flag);
    }

    const business = await prisma.business.findUnique({
      where: { id: businessId },
      select: { [flag]: true },
    });

    if (!business || !(business as Record<string, unknown>)[flag]) {
      throw new FeatureDisabledError(flag);
    }
  };
}
