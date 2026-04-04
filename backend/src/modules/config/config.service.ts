import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';

export async function getBusinessConfig(businessId: string) {
  const business = await prisma.business.findUnique({ where: { id: businessId } });
  if (!business) throw new NotFoundError('Business', businessId);
  return business;
}

export async function updateBusinessConfig(businessId: string, data: Record<string, unknown>) {
  return prisma.business.update({ where: { id: businessId }, data });
}

export async function getFeatureFlags(businessId: string) {
  const business = await prisma.business.findUnique({
    where: { id: businessId },
    select: {
      enableDispatch: true, enableReconciliation: true, enableWastageMargin: true,
      enableBatchExpiry: true, enableAppointments: true, enableCreditLedger: true,
      enableWeightBilling: true, enableCommissions: true, enableMemberships: true,
      enableBarcode: true, enableDelivery: true, enableAggregators: true,
      enableAnomaly: true, enablePerformance: true, enableWeather: true, enableLoyalty: true,
    },
  });
  if (!business) throw new NotFoundError('Business', businessId);
  return business;
}
