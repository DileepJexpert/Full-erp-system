import { prisma } from '../../lib/prisma.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';

interface CreateLocationInput {
  name: string;
  type: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  upiId?: string;
  razorpayAccountId?: string;
  printerType?: string;
  receiptHeader?: string;
  receiptFooter?: string;
  fssaiNumber?: string;
  dailyExpenseLimit?: number;
  staffId?: string;
  managerId?: string;
}

interface UpdateLocationInput extends Partial<CreateLocationInput> {}

export async function createLocation(businessId: string, input: CreateLocationInput) {
  const business = await prisma.business.findUnique({
    where: { id: businessId },
    select: { maxLocations: true },
  });
  if (!business) throw new NotFoundError('Business', businessId);

  const locationCount = await prisma.location.count({
    where: { businessId, isActive: true },
  });
  if (locationCount >= business.maxLocations) {
    throw new BadRequestError(
      `Location limit reached. Your plan allows a maximum of ${business.maxLocations} active locations.`,
    );
  }

  const { staffId, managerId, ...rest } = input;

  return prisma.location.create({
    data: {
      ...rest,
      businessId,
      ...(staffId && { staffId }),
      ...(managerId && { managerId }),
    },
    include: { staff: true, manager: true },
  });
}

export async function getLocations(businessId: string) {
  return prisma.location.findMany({
    where: { businessId, isActive: true },
    include: { staff: true, manager: true },
    orderBy: { name: 'asc' },
  });
}

export async function getLocationById(businessId: string, id: string) {
  const location = await prisma.location.findFirst({
    where: { id, businessId },
    include: { staff: true, manager: true },
  });
  if (!location) throw new NotFoundError('Location', id);
  return location;
}

export async function updateLocation(businessId: string, id: string, input: UpdateLocationInput) {
  const location = await prisma.location.findFirst({ where: { id, businessId } });
  if (!location) throw new NotFoundError('Location', id);

  return prisma.location.update({
    where: { id },
    data: input,
    include: { staff: true, manager: true },
  });
}

export async function deleteLocation(businessId: string, id: string) {
  const location = await prisma.location.findFirst({ where: { id, businessId } });
  if (!location) throw new NotFoundError('Location', id);

  return prisma.location.update({
    where: { id },
    data: { isActive: false },
  });
}
