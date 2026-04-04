import { PrismaClient } from '@prisma/client';
import { AsyncLocalStorage } from 'node:async_hooks';

export interface TenantStore {
  businessId: string;
}

export const asyncLocalStorage = new AsyncLocalStorage<TenantStore>();

const TENANT_SCOPED_MODELS = new Set([
  'User', 'Location', 'Item', 'ItemVariant', 'Season', 'MenuTemplate',
  'MenuTemplateItem', 'Dispatch', 'DispatchItem', 'Bill', 'BillItem',
  'Reconciliation', 'ReconItem', 'SalaryRecord', 'Advance', 'Attendance',
  'CashCollection', 'Expense', 'Supplier', 'Purchase', 'PurchaseItem',
  'Customer', 'Alert', 'ComplianceDoc', 'WeatherLog',
]);

function createPrismaClient(): PrismaClient {
  const client = new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });

  client.$use(async (params, next) => {
    const store = asyncLocalStorage.getStore();
    const tenantId = store?.businessId;

    if (!tenantId || !params.model || !TENANT_SCOPED_MODELS.has(params.model)) {
      return next(params);
    }

    // Auto-inject businessId into WHERE clauses
    if (['findUnique', 'findFirst', 'findMany', 'count', 'aggregate', 'groupBy'].includes(params.action)) {
      if (!params.args) params.args = {};
      if (!params.args.where) params.args.where = {};
      params.args.where.businessId = tenantId;
    }

    if (['update', 'updateMany'].includes(params.action)) {
      if (!params.args) params.args = {};
      if (!params.args.where) params.args.where = {};
      params.args.where.businessId = tenantId;
    }

    if (['delete', 'deleteMany'].includes(params.action)) {
      if (!params.args) params.args = {};
      if (!params.args.where) params.args.where = {};
      params.args.where.businessId = tenantId;
    }

    // Auto-inject businessId into CREATE data
    if (params.action === 'create') {
      if (!params.args) params.args = {};
      if (!params.args.data) params.args.data = {};
      if (!params.args.data.businessId) {
        params.args.data.businessId = tenantId;
      }
    }

    if (params.action === 'createMany') {
      if (!params.args) params.args = {};
      if (Array.isArray(params.args.data)) {
        params.args.data = params.args.data.map((d: Record<string, unknown>) => ({
          ...d,
          businessId: d.businessId ?? tenantId,
        }));
      }
    }

    // Upsert
    if (params.action === 'upsert') {
      if (!params.args) params.args = {};
      if (!params.args.where) params.args.where = {};
      params.args.where.businessId = tenantId;
      if (!params.args.create) params.args.create = {};
      if (!params.args.create.businessId) {
        params.args.create.businessId = tenantId;
      }
    }

    return next(params);
  });

  return client;
}

declare const globalThis: {
  prismaGlobal: PrismaClient | undefined;
} & typeof global;

export const prisma = globalThis.prismaGlobal ?? createPrismaClient();

if (process.env.NODE_ENV !== 'production') {
  globalThis.prismaGlobal = prisma;
}
