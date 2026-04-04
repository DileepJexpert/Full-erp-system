import { AsyncLocalStorage } from 'node:async_hooks';
import { PrismaClient, Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma.js';

export interface AuditStore {
  userId: string;
  userName: string;
  businessId: string;
  ipAddress?: string;
}

export const auditStorage = new AsyncLocalStorage<AuditStore>();

const AUDITABLE_MODELS = new Set([
  'Bill',
  'Reconciliation',
  'SalaryRecord',
  'Item',
  'CashCollection',
  'Expense',
  'Dispatch',
  'Attendance',
  'Purchase',
]);

const WRITE_ACTIONS = new Set(['create', 'update', 'delete']);

/**
 * Prisma middleware that auto-logs CREATE/UPDATE/DELETE operations
 * for key entities into the AuditLog table.
 *
 * Must be registered via `prisma.$use(auditMiddleware)`.
 */
export const auditMiddleware: Prisma.Middleware = async (params, next) => {
  if (
    !params.model ||
    !AUDITABLE_MODELS.has(params.model) ||
    !WRITE_ACTIONS.has(params.action)
  ) {
    return next(params);
  }

  const store = auditStorage.getStore();
  if (!store) {
    // No audit context available (e.g. system/seed operations) - skip logging
    return next(params);
  }

  const { userId, userName, businessId, ipAddress } = store;
  const model = params.model;

  // ── DELETE: capture entity before removal ──
  if (params.action === 'delete') {
    let oldValue: unknown = null;
    try {
      oldValue = await (prisma as any)[lowerFirst(model)].findUnique({
        where: params.args.where,
      });
    } catch {
      // best-effort
    }

    const result = await next(params);

    await writeAuditLog({
      entityType: model,
      entityId: extractId(params.args.where),
      action: 'DELETE',
      oldValue: oldValue as any,
      newValue: null,
      userId,
      userName,
      businessId,
      ipAddress: ipAddress ?? null,
    });

    return result;
  }

  // ── UPDATE: capture old value, then new value ──
  if (params.action === 'update') {
    let oldValue: unknown = null;
    try {
      oldValue = await (prisma as any)[lowerFirst(model)].findUnique({
        where: params.args.where,
      });
    } catch {
      // best-effort
    }

    const result = await next(params);

    await writeAuditLog({
      entityType: model,
      entityId: extractId(params.args.where) || (result as any)?.id,
      action: 'UPDATE',
      oldValue: oldValue as any,
      newValue: result as any,
      userId,
      userName,
      businessId,
      ipAddress: ipAddress ?? null,
    });

    return result;
  }

  // ── CREATE: log the created entity ──
  if (params.action === 'create') {
    const result = await next(params);

    await writeAuditLog({
      entityType: model,
      entityId: (result as any)?.id ?? '',
      action: 'CREATE',
      oldValue: null,
      newValue: result as any,
      userId,
      userName,
      businessId,
      ipAddress: ipAddress ?? null,
    });

    return result;
  }

  return next(params);
};

// ── helpers ──

function lowerFirst(s: string): string {
  return s.charAt(0).toLowerCase() + s.slice(1);
}

function extractId(where: Record<string, unknown> | undefined): string {
  if (!where) return '';
  if (typeof where.id === 'string') return where.id;
  return '';
}

async function writeAuditLog(data: {
  entityType: string;
  entityId: string;
  action: string;
  oldValue: Prisma.InputJsonValue | null;
  newValue: Prisma.InputJsonValue | null;
  userId: string;
  userName: string;
  businessId: string;
  ipAddress: string | null;
}): Promise<void> {
  try {
    await prisma.auditLog.create({ data });
  } catch (err) {
    // Never let audit failures break the main operation
    console.error('[AuditMiddleware] Failed to write audit log:', err);
  }
}
