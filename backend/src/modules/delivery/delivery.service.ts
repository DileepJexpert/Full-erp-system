import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';

interface RecordDeliveryProofData {
  photoUrl?: string;
  signatureUrl?: string;
  gpsLatitude?: number;
  gpsLongitude?: number;
  receiverName?: string;
  notes?: string;
  dispatchId?: string;
  billId?: string;
  deliveredById: string;
}

interface DeliveryProofFilters {
  startDate?: string;
  endDate?: string;
  deliveredById?: string;
  page?: number;
  limit?: number;
}

export async function recordDeliveryProof(businessId: string, data: RecordDeliveryProofData) {
  const now = new Date();

  // If dispatchId provided, verify it exists and update dispatch with delivery fields
  if (data.dispatchId) {
    const dispatch = await prisma.dispatch.findFirst({
      where: { id: data.dispatchId, businessId },
    });
    if (!dispatch) throw new NotFoundError('Dispatch', data.dispatchId);

    // Use a transaction to create proof and update dispatch atomically
    return prisma.$transaction(async (tx) => {
      const proof = await tx.deliveryProof.create({
        data: {
          photoUrl: data.photoUrl,
          signatureUrl: data.signatureUrl,
          gpsLatitude: data.gpsLatitude,
          gpsLongitude: data.gpsLongitude,
          deliveredAt: now,
          receiverName: data.receiverName,
          notes: data.notes,
          businessId,
          dispatchId: data.dispatchId,
          billId: data.billId,
          deliveredById: data.deliveredById,
        },
      });

      await tx.dispatch.update({
        where: { id: data.dispatchId! },
        data: {
          deliveryPhotoUrl: data.photoUrl,
          deliverySignUrl: data.signatureUrl,
          deliveryGpsLat: data.gpsLatitude,
          deliveryGpsLng: data.gpsLongitude,
          deliveredAt: now,
          deliveredById: data.deliveredById,
        },
      });

      return proof;
    });
  }

  return prisma.deliveryProof.create({
    data: {
      photoUrl: data.photoUrl,
      signatureUrl: data.signatureUrl,
      gpsLatitude: data.gpsLatitude,
      gpsLongitude: data.gpsLongitude,
      deliveredAt: now,
      receiverName: data.receiverName,
      notes: data.notes,
      businessId,
      billId: data.billId,
      deliveredById: data.deliveredById,
    },
  });
}

export async function getDeliveryProof(businessId: string, filters: DeliveryProofFilters) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 50;
  const skip = (page - 1) * limit;

  const where: Record<string, unknown> = { businessId };

  if (filters.startDate || filters.endDate) {
    where.deliveredAt = {};
    if (filters.startDate) (where.deliveredAt as Record<string, unknown>).gte = new Date(filters.startDate);
    if (filters.endDate) (where.deliveredAt as Record<string, unknown>).lte = new Date(filters.endDate);
  }

  if (filters.deliveredById) where.deliveredById = filters.deliveredById;

  const [data, total] = await Promise.all([
    prisma.deliveryProof.findMany({
      where,
      orderBy: { deliveredAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.deliveryProof.count({ where }),
  ]);

  return { data, total, page, limit };
}

export async function getDeliveryProofById(businessId: string, id: string) {
  const proof = await prisma.deliveryProof.findFirst({
    where: { id, businessId },
  });
  if (!proof) throw new NotFoundError('DeliveryProof', id);
  return proof;
}

export async function getDeliveryProofByDispatch(businessId: string, dispatchId: string) {
  const proof = await prisma.deliveryProof.findFirst({
    where: { businessId, dispatchId },
  });
  if (!proof) throw new NotFoundError('DeliveryProof for dispatch', dispatchId);
  return proof;
}
