import { prisma } from '../../lib/prisma.js';
import { NotFoundError, BadRequestError } from '../../utils/errors.js';
import type { CreateItemInput, UpdateItemInput, ItemQuery } from './inventory.schema.js';

export async function createItem(businessId: string, input: CreateItemInput) {
  return prisma.item.create({
    data: { ...input, businessId, seasonTags: input.seasonTags as any[] },
  });
}

export async function getItems(businessId: string, query: ItemQuery) {
  const where: Record<string, unknown> = { businessId };
  if (query.category) where.category = query.category;
  if (query.isActive !== undefined) where.isActive = query.isActive;
  if (query.search) where.name = { contains: query.search, mode: 'insensitive' };

  const [items, total] = await Promise.all([
    prisma.item.findMany({
      where,
      include: { variants: true },
      orderBy: { name: 'asc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.item.count({ where }),
  ]);

  return {
    data: items,
    pagination: { page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) },
  };
}

export async function getItemById(businessId: string, id: string) {
  const item = await prisma.item.findFirst({
    where: { id, businessId },
    include: { variants: true },
  });
  if (!item) throw new NotFoundError('Item', id);
  return item;
}

export async function updateItem(businessId: string, id: string, input: UpdateItemInput) {
  const item = await prisma.item.findFirst({ where: { id, businessId } });
  if (!item) throw new NotFoundError('Item', id);

  return prisma.item.update({
    where: { id },
    data: { ...input, seasonTags: input.seasonTags as any[] },
  });
}

export async function deleteItem(businessId: string, id: string) {
  const item = await prisma.item.findFirst({ where: { id, businessId } });
  if (!item) throw new NotFoundError('Item', id);

  return prisma.item.update({
    where: { id },
    data: { isActive: false },
  });
}
