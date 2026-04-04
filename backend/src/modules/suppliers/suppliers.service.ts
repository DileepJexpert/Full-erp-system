import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';
import type { CreateSupplierInput, UpdateSupplierInput } from './suppliers.schema.js';

export async function createSupplier(businessId: string, input: CreateSupplierInput) {
  return prisma.supplier.create({
    data: { ...input, paymentTerms: input.paymentTerms as any, businessId },
  });
}

export async function getSuppliers(businessId: string) {
  return prisma.supplier.findMany({
    where: { businessId, isActive: true },
    orderBy: { name: 'asc' },
  });
}

export async function getSupplierById(businessId: string, id: string) {
  const supplier = await prisma.supplier.findFirst({
    where: { id, businessId },
    include: { purchases: { orderBy: { date: 'desc' }, take: 10 } },
  });
  if (!supplier) throw new NotFoundError('Supplier', id);
  return supplier;
}

export async function updateSupplier(businessId: string, id: string, input: UpdateSupplierInput) {
  const supplier = await prisma.supplier.findFirst({ where: { id, businessId } });
  if (!supplier) throw new NotFoundError('Supplier', id);

  return prisma.supplier.update({
    where: { id },
    data: { ...input, paymentTerms: input.paymentTerms as any },
  });
}

export async function deleteSupplier(businessId: string, id: string) {
  const supplier = await prisma.supplier.findFirst({ where: { id, businessId } });
  if (!supplier) throw new NotFoundError('Supplier', id);

  return prisma.supplier.update({
    where: { id },
    data: { isActive: false },
  });
}
