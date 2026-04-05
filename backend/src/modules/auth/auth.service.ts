import { prisma } from '../../lib/prisma.js';
import { sendOtp as sendOtpSms, verifyOtp as verifyOtpSms } from '../../lib/msg91.js';
import { signToken } from '../../plugins/auth.js';
import { DEFAULT_FEATURE_FLAGS } from '../../config/constants.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';
import type { RegisterBusinessInput, AddUserInput } from './auth.schema.js';
import { seedBusinessDefaults } from '../../lib/seed-defaults.js';

export async function sendOtp(phone: string) {
  const result = await sendOtpSms(phone);
  if (!result.success) {
    throw new BadRequestError('Failed to send OTP');
  }
  return { success: true, message: 'OTP sent successfully' };
}

export async function verifyOtpAndLogin(phone: string, otp: string, businessId?: string) {
  const isValid = await verifyOtpSms(phone, otp);
  if (!isValid) {
    throw new BadRequestError('Invalid OTP');
  }

  // Find user(s) with this phone
  const whereClause: Record<string, unknown> = { phone };
  if (businessId) {
    whereClause.businessId = businessId;
  }

  const users = await prisma.user.findMany({
    where: whereClause,
    include: { business: { select: { id: true, name: true, type: true } } },
  });

  if (users.length === 0) {
    throw new NotFoundError('User', `phone:${phone}`);
  }

  // If multiple businesses, return first or the one matching businessId
  const user = businessId
    ? users.find((u) => u.businessId === businessId) ?? users[0]
    : users[0];

  const token = signToken({
    userId: user.id,
    businessId: user.businessId,
    role: user.role,
    phone: user.phone,
  });

  return {
    token,
    user: {
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      businessId: user.businessId,
      businessName: user.business.name,
      businessType: user.business.type,
    },
    // If user belongs to multiple businesses, return the list
    ...(users.length > 1 && {
      businesses: users.map((u) => ({
        businessId: u.businessId,
        businessName: u.business.name,
        role: u.role,
      })),
    }),
  };
}

export async function registerBusiness(input: RegisterBusinessInput) {
  const flags = DEFAULT_FEATURE_FLAGS[input.businessType] ?? {};

  const business = await prisma.business.create({
    data: {
      name: input.businessName,
      type: input.businessType as any,
      phone: input.phone,
      email: input.email,
      enableDispatch: flags.enableDispatch ?? false,
      enableReconciliation: flags.enableReconciliation ?? false,
      enableWastageMargin: flags.enableWastageMargin ?? false,
      enableBatchExpiry: flags.enableBatchExpiry ?? false,
      enableAppointments: flags.enableAppointments ?? false,
      enableCreditLedger: flags.enableCreditLedger ?? false,
      enableWeightBilling: flags.enableWeightBilling ?? false,
      enableCommissions: flags.enableCommissions ?? false,
      enableMemberships: flags.enableMemberships ?? false,
      enableBarcode: flags.enableBarcode ?? false,
      enableDelivery: flags.enableDelivery ?? false,
      enableAggregators: flags.enableAggregators ?? false,
      enableWeather: flags.enableWeather ?? false,
      users: {
        create: {
          name: input.ownerName,
          phone: input.phone,
          role: 'OWNER',
        },
      },
    },
    include: {
      users: true,
    },
  });

  // Seed default items and terminology for this business type
  await seedBusinessDefaults(business.id, input.businessType);

  const owner = business.users[0];
  const token = signToken({
    userId: owner.id,
    businessId: business.id,
    role: 'OWNER',
    phone: owner.phone,
  });

  return {
    token,
    business: { id: business.id, name: business.name, type: business.type },
    user: { id: owner.id, name: owner.name, phone: owner.phone, role: owner.role },
  };
}

export async function addUser(businessId: string, input: AddUserInput) {
  const existing = await prisma.user.findUnique({
    where: { phone_businessId: { phone: input.phone, businessId } },
  });

  if (existing) {
    throw new BadRequestError('User with this phone already exists in this business');
  }

  const business = await prisma.business.findUnique({
    where: { id: businessId },
    select: { maxStaff: true, _count: { select: { users: true } } },
  });

  if (business && business._count.users >= business.maxStaff) {
    throw new BadRequestError(`Maximum staff limit (${business.maxStaff}) reached`);
  }

  return prisma.user.create({
    data: {
      ...input,
      role: input.role as any,
      salaryType: input.salaryType as any,
      businessId,
    },
  });
}

export async function getUsers(businessId: string) {
  return prisma.user.findMany({
    where: { businessId },
    include: {
      assignedLocation: { select: { id: true, name: true } },
    },
    orderBy: { createdAt: 'desc' },
  });
}

export async function getMe(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      business: true,
      assignedLocation: { select: { id: true, name: true, type: true } },
    },
  });

  if (!user) throw new NotFoundError('User', userId);
  return user;
}
