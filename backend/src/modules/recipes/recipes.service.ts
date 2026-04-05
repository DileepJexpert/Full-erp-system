import { prisma } from '../../lib/prisma.js';
import { BadRequestError, NotFoundError } from '../../utils/errors.js';

interface IngredientInput {
  ingredientItemId: string;
  quantity: number;
  unit: string;
  wastagePercent?: number;
}

interface CreateRecipeInput {
  name: string;
  outputItemId: string;
  outputQty: number;
  outputUnit: string;
  notes?: string;
  ingredients: IngredientInput[];
}

interface UpdateRecipeInput {
  name?: string;
  outputQty?: number;
  outputUnit?: string;
  notes?: string;
  ingredients?: IngredientInput[];
}

export async function createRecipe(businessId: string, data: CreateRecipeInput) {
  if (data.ingredients.length === 0) {
    throw new BadRequestError('At least one ingredient is required');
  }

  const existingRecipe = await prisma.recipe.findUnique({
    where: { outputItemId_businessId: { outputItemId: data.outputItemId, businessId } },
  });

  if (existingRecipe) {
    throw new BadRequestError('A recipe already exists for this output item');
  }

  return prisma.recipe.create({
    data: {
      name: data.name,
      outputItemId: data.outputItemId,
      outputQty: data.outputQty,
      outputUnit: data.outputUnit,
      notes: data.notes,
      businessId,
      ingredients: {
        create: data.ingredients.map((ing) => ({
          ingredientItemId: ing.ingredientItemId,
          quantity: ing.quantity,
          unit: ing.unit,
          wastagePercent: ing.wastagePercent ?? 0,
        })),
      },
    },
    include: { ingredients: true },
  });
}

export async function updateRecipe(businessId: string, id: string, data: UpdateRecipeInput) {
  const recipe = await prisma.recipe.findFirst({
    where: { id, businessId, isActive: true },
  });

  if (!recipe) {
    throw new NotFoundError('Recipe', id);
  }

  return prisma.$transaction(async (tx) => {
    // If ingredients are being updated, delete old and create new
    if (data.ingredients) {
      if (data.ingredients.length === 0) {
        throw new BadRequestError('At least one ingredient is required');
      }

      await tx.recipeIngredient.deleteMany({ where: { recipeId: id } });

      await tx.recipeIngredient.createMany({
        data: data.ingredients.map((ing) => ({
          recipeId: id,
          ingredientItemId: ing.ingredientItemId,
          quantity: ing.quantity,
          unit: ing.unit,
          wastagePercent: ing.wastagePercent ?? 0,
        })),
      });
    }

    return tx.recipe.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.outputQty !== undefined && { outputQty: data.outputQty }),
        ...(data.outputUnit !== undefined && { outputUnit: data.outputUnit }),
        ...(data.notes !== undefined && { notes: data.notes }),
      },
      include: { ingredients: true },
    });
  });
}

export async function getRecipes(businessId: string) {
  return prisma.recipe.findMany({
    where: { businessId, isActive: true },
    include: { ingredients: true },
    orderBy: { name: 'asc' },
  });
}

export async function getRecipe(businessId: string, id: string) {
  const recipe = await prisma.recipe.findFirst({
    where: { id, businessId, isActive: true },
    include: { ingredients: true },
  });

  if (!recipe) {
    throw new NotFoundError('Recipe', id);
  }

  return recipe;
}

export async function deleteRecipe(businessId: string, id: string) {
  const recipe = await prisma.recipe.findFirst({
    where: { id, businessId, isActive: true },
  });

  if (!recipe) {
    throw new NotFoundError('Recipe', id);
  }

  return prisma.recipe.update({
    where: { id },
    data: { isActive: false },
  });
}

export async function calculateConsumption(businessId: string, itemId: string, quantity: number) {
  const recipe = await prisma.recipe.findFirst({
    where: { outputItemId: itemId, businessId, isActive: true },
    include: { ingredients: true },
  });

  if (!recipe) {
    throw new NotFoundError('Recipe for item', itemId);
  }

  if (quantity <= 0) {
    throw new BadRequestError('Quantity must be positive');
  }

  const consumption = recipe.ingredients.map((ing) => {
    const baseQty = (quantity * ing.quantity) / recipe.outputQty;
    const withWastage = baseQty * (1 + ing.wastagePercent / 100);
    return {
      ingredientItemId: ing.ingredientItemId,
      unit: ing.unit,
      baseQuantity: Math.round(baseQty * 1000) / 1000,
      withWastage: Math.round(withWastage * 1000) / 1000,
      wastagePercent: ing.wastagePercent,
    };
  });

  return {
    recipeId: recipe.id,
    recipeName: recipe.name,
    outputItemId: itemId,
    outputQty: quantity,
    ingredients: consumption,
  };
}

export async function deductRawMaterials(businessId: string, itemId: string, dispatchQty: number) {
  const recipe = await prisma.recipe.findFirst({
    where: { outputItemId: itemId, businessId, isActive: true },
    include: { ingredients: true },
  });

  if (!recipe) {
    throw new NotFoundError('Recipe for item', itemId);
  }

  if (dispatchQty <= 0) {
    throw new BadRequestError('Dispatch quantity must be positive');
  }

  return prisma.$transaction(async (tx) => {
    const deductions = [];

    for (const ing of recipe.ingredients) {
      const baseQty = (dispatchQty * ing.quantity) / recipe.outputQty;
      const deductQty = baseQty * (1 + ing.wastagePercent / 100);
      const roundedDeductQty = Math.round(deductQty * 1000) / 1000;

      const item = await tx.item.findUnique({ where: { id: ing.ingredientItemId } });
      if (!item) {
        throw new NotFoundError('Ingredient item', ing.ingredientItemId);
      }

      if (item.centralStock < roundedDeductQty) {
        throw new BadRequestError(
          `Insufficient stock for ingredient '${item.name}': available ${item.centralStock}, required ${roundedDeductQty}`,
        );
      }

      await tx.item.update({
        where: { id: ing.ingredientItemId },
        data: { centralStock: { decrement: roundedDeductQty } },
      });

      deductions.push({
        ingredientItemId: ing.ingredientItemId,
        ingredientName: item.name,
        quantityDeducted: roundedDeductQty,
        unit: ing.unit,
        remainingStock: item.centralStock - roundedDeductQty,
      });
    }

    return {
      recipeId: recipe.id,
      recipeName: recipe.name,
      dispatchQty,
      deductions,
    };
  });
}
