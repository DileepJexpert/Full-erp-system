import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';

interface CreateTemplateInput {
  name: string;
  locationType: string;
  seasonId?: string;
  items: Array<{ itemId: string; defaultQty: number }>;
}

interface CreateSeasonInput {
  name: string;
  type: string;
  startDate: string;
  endDate: string;
}

export async function createTemplate(businessId: string, input: CreateTemplateInput) {
  return prisma.menuTemplate.create({
    data: {
      businessId,
      name: input.name,
      locationType: input.locationType,
      seasonId: input.seasonId,
      items: {
        create: input.items.map((i) => ({
          itemId: i.itemId,
          defaultQty: i.defaultQty,
        })),
      },
    },
    include: { items: { include: { item: true } }, season: true },
  });
}

export async function getTemplates(businessId: string) {
  return prisma.menuTemplate.findMany({
    where: { businessId },
    include: { items: { include: { item: true } }, season: true, activeLocations: { select: { id: true, name: true } } },
    orderBy: { name: 'asc' },
  });
}

export async function getTemplateById(businessId: string, id: string) {
  const template = await prisma.menuTemplate.findFirst({
    where: { id, businessId },
    include: { items: { include: { item: true } }, season: true, activeLocations: true },
  });
  if (!template) throw new NotFoundError('MenuTemplate', id);
  return template;
}

export async function updateTemplate(businessId: string, id: string, input: Partial<CreateTemplateInput>) {
  const template = await prisma.menuTemplate.findFirst({ where: { id, businessId } });
  if (!template) throw new NotFoundError('MenuTemplate', id);

  if (input.items) {
    await prisma.menuTemplateItem.deleteMany({ where: { templateId: id } });
    await prisma.menuTemplateItem.createMany({
      data: input.items.map((i) => ({ templateId: id, itemId: i.itemId, defaultQty: i.defaultQty })),
    });
  }

  return prisma.menuTemplate.update({
    where: { id },
    data: {
      name: input.name,
      locationType: input.locationType,
      seasonId: input.seasonId,
    },
    include: { items: { include: { item: true } } },
  });
}

export async function deleteTemplate(businessId: string, id: string) {
  const template = await prisma.menuTemplate.findFirst({ where: { id, businessId } });
  if (!template) throw new NotFoundError('MenuTemplate', id);
  await prisma.menuTemplateItem.deleteMany({ where: { templateId: id } });
  return prisma.menuTemplate.delete({ where: { id } });
}

export async function createSeason(businessId: string, input: CreateSeasonInput) {
  return prisma.season.create({
    data: {
      businessId,
      name: input.name,
      type: input.type as any,
      startDate: new Date(input.startDate),
      endDate: new Date(input.endDate),
    },
  });
}

export async function getSeasons(businessId: string) {
  return prisma.season.findMany({
    where: { businessId },
    include: { templates: { select: { id: true, name: true } } },
    orderBy: { startDate: 'desc' },
  });
}

export async function activateSeason(businessId: string, seasonId: string) {
  // Deactivate all seasons, activate this one
  await prisma.season.updateMany({ where: { businessId }, data: { isActive: false } });
  return prisma.season.update({ where: { id: seasonId }, data: { isActive: true } });
}
