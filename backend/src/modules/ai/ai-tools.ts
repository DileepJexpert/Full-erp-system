import type Anthropic from '@anthropic-ai/sdk';
import { prisma } from '../../lib/prisma.js';

// ── Tool definitions for Claude tool-use ─────────────────────────

export const AI_TOOLS: Anthropic.Tool[] = [
  {
    name: 'getRevenueByLocation',
    description:
      'Get revenue breakdown by location for a date range. Returns total revenue, bill count, cash, and UPI per location.',
    input_schema: {
      type: 'object' as const,
      properties: {
        startDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        endDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
      },
      required: ['startDate', 'endDate'],
    },
  },
  {
    name: 'getWastageByOperator',
    description:
      'Get wastage/loss amounts grouped by operator for a date range. Helps identify which operators have highest losses.',
    input_schema: {
      type: 'object' as const,
      properties: {
        startDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        endDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
      },
      required: ['startDate', 'endDate'],
    },
  },
  {
    name: 'getExpenseBreakdown',
    description:
      'Get expenses grouped by category for a date range.',
    input_schema: {
      type: 'object' as const,
      properties: {
        startDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        endDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
      },
      required: ['startDate', 'endDate'],
    },
  },
  {
    name: 'getStockLevels',
    description:
      'Get current stock levels for all items, including items below minimum stock threshold.',
    input_schema: {
      type: 'object' as const,
      properties: {},
      required: [],
    },
  },
  {
    name: 'getOperatorPerformance',
    description:
      'Get operator performance metrics: bills created, revenue generated, attendance, losses.',
    input_schema: {
      type: 'object' as const,
      properties: {
        startDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        endDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
      },
      required: ['startDate', 'endDate'],
    },
  },
  {
    name: 'getTopSellingItems',
    description:
      'Get top selling items by quantity or revenue for a date range.',
    input_schema: {
      type: 'object' as const,
      properties: {
        startDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        endDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        limit: { type: 'number', description: 'Number of items to return (default 10)' },
        sortBy: { type: 'string', enum: ['quantity', 'revenue'], description: 'Sort by quantity sold or revenue (default revenue)' },
      },
      required: ['startDate', 'endDate'],
    },
  },
  {
    name: 'getAlerts',
    description:
      'Get active alerts for the business: low stock, anomalies, pending reconciliations, etc.',
    input_schema: {
      type: 'object' as const,
      properties: {
        status: { type: 'string', enum: ['ACTIVE', 'RESOLVED', 'ALL'], description: 'Filter by alert status (default ACTIVE)' },
      },
      required: [],
    },
  },
  {
    name: 'getSalaryDetails',
    description:
      'Get salary details for all staff or a specific user. Shows base salary, deductions, advances, net pay.',
    input_schema: {
      type: 'object' as const,
      properties: {
        userId: { type: 'string', description: 'Optional user ID. If omitted, returns all staff.' },
        month: { type: 'string', description: 'Month in YYYY-MM format. Defaults to current month.' },
      },
      required: [],
    },
  },
  {
    name: 'getPurchasePriceHistory',
    description:
      'Get purchase price history for a specific item or all items. Helps track price trends from suppliers.',
    input_schema: {
      type: 'object' as const,
      properties: {
        itemId: { type: 'string', description: 'Optional item ID. If omitted, returns all items.' },
        days: { type: 'number', description: 'Number of days of history (default 30)' },
      },
      required: [],
    },
  },
  {
    name: 'getCustomerStats',
    description:
      'Get customer statistics: total customers, repeat rate, loyalty points distribution, top customers by spend.',
    input_schema: {
      type: 'object' as const,
      properties: {
        startDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        endDate: { type: 'string', description: 'ISO date string YYYY-MM-DD' },
        limit: { type: 'number', description: 'Top N customers (default 10)' },
      },
      required: [],
    },
  },
];

// ── Tool execution ───────────────────────────────────────────────

export async function executeTool(
  name: string,
  args: Record<string, unknown>,
  businessId: string,
): Promise<unknown> {
  switch (name) {
    case 'getRevenueByLocation': {
      const start = new Date(args.startDate as string);
      const end = new Date(args.endDate as string);
      end.setHours(23, 59, 59, 999);

      const bills = await prisma.bill.findMany({
        where: { businessId, date: { gte: start, lte: end } },
        include: { location: { select: { id: true, name: true } } },
      });

      const byLocation = new Map<string, { name: string; revenue: number; bills: number; cash: number; upi: number }>();

      for (const bill of bills) {
        const locId = bill.locationId;
        const existing = byLocation.get(locId) ?? {
          name: (bill as any).location?.name ?? locId,
          revenue: 0,
          bills: 0,
          cash: 0,
          upi: 0,
        };
        existing.revenue += bill.total as number;
        existing.bills += 1;
        existing.cash += (bill.cashAmount as number) || 0;
        existing.upi += (bill.upiAmount as number) || 0;
        byLocation.set(locId, existing);
      }

      return {
        totalRevenue: bills.reduce((s, b) => s + (b.total as number), 0),
        totalBills: bills.length,
        locations: Array.from(byLocation.entries()).map(([id, data]) => ({ id, ...data })),
      };
    }

    case 'getWastageByOperator': {
      const start = new Date(args.startDate as string);
      const end = new Date(args.endDate as string);
      end.setHours(23, 59, 59, 999);

      const recons = await prisma.reconciliation.findMany({
        where: { businessId, date: { gte: start, lte: end } },
        select: {
          operatorId: true,
          totalLoss: true,
        },
      });

      const byOperator = new Map<string, { totalLoss: number; reconCount: number }>();
      for (const r of recons) {
        const existing = byOperator.get(r.operatorId) ?? { totalLoss: 0, reconCount: 0 };
        existing.totalLoss += r.totalLoss as number;
        existing.reconCount += 1;
        byOperator.set(r.operatorId, existing);
      }

      // Resolve operator names
      const operatorIds = Array.from(byOperator.keys());
      const users = await prisma.user.findMany({
        where: { id: { in: operatorIds } },
        select: { id: true, name: true },
      });
      const nameMap = new Map(users.map((u) => [u.id, u.name]));

      return Array.from(byOperator.entries()).map(([id, data]) => ({
        operatorId: id,
        operatorName: nameMap.get(id) ?? 'Unknown',
        ...data,
      }));
    }

    case 'getExpenseBreakdown': {
      const start = new Date(args.startDate as string);
      const end = new Date(args.endDate as string);
      end.setHours(23, 59, 59, 999);

      const expenses = await prisma.expense.findMany({
        where: { businessId, date: { gte: start, lte: end } },
      });

      const byCategory = new Map<string, number>();
      let total = 0;
      for (const e of expenses) {
        const cat = (e as any).category ?? 'Uncategorized';
        byCategory.set(cat, (byCategory.get(cat) ?? 0) + (e.amount as number));
        total += e.amount as number;
      }

      return {
        total,
        categories: Array.from(byCategory.entries()).map(([category, amount]) => ({
          category,
          amount,
        })),
      };
    }

    case 'getStockLevels': {
      const items = await prisma.item.findMany({
        where: { businessId },
        select: {
          id: true,
          name: true,
          centralStock: true,
          minStockLevel: true,
          unit: true,
        },
        orderBy: { centralStock: 'asc' },
      });

      const lowStock = items.filter(
        (i) => (i.centralStock ?? 0) <= (i.minStockLevel ?? 0),
      );

      return {
        totalItems: items.length,
        lowStockCount: lowStock.length,
        items: items.map((i) => ({
          id: i.id,
          name: i.name,
          currentStock: i.centralStock,
          minStock: i.minStockLevel,
          unit: i.unit,
          isLow: (i.centralStock ?? 0) <= (i.minStockLevel ?? 0),
        })),
      };
    }

    case 'getOperatorPerformance': {
      const start = new Date(args.startDate as string);
      const end = new Date(args.endDate as string);
      end.setHours(23, 59, 59, 999);

      const users = await prisma.user.findMany({
        where: { businessId, role: { in: ['STAFF', 'MANAGER'] } },
        select: { id: true, name: true, role: true },
      });

      const performances = await Promise.all(
        users.map(async (user) => {
          const [billAgg, reconAgg, attendanceCount] = await Promise.all([
            prisma.bill.aggregate({
              where: { businessId, operatorId: user.id, date: { gte: start, lte: end } },
              _sum: { total: true },
              _count: { id: true },
            }),
            prisma.reconciliation.aggregate({
              where: { businessId, operatorId: user.id, date: { gte: start, lte: end } },
              _sum: { totalLoss: true },
            }),
            prisma.attendance.count({
              where: { businessId, operatorId: user.id, date: { gte: start, lte: end } },
            }),
          ]);

          return {
            userId: user.id,
            name: user.name,
            role: user.role,
            billCount: billAgg._count.id,
            revenue: billAgg._sum.total ?? 0,
            totalLoss: reconAgg._sum.totalLoss ?? 0,
            daysPresent: attendanceCount,
          };
        }),
      );

      return performances;
    }

    case 'getTopSellingItems': {
      const start = new Date(args.startDate as string);
      const end = new Date(args.endDate as string);
      end.setHours(23, 59, 59, 999);
      const limit = (args.limit as number) || 10;
      const sortBy = (args.sortBy as string) || 'revenue';

      const billItems = await prisma.billItem.findMany({
        where: {
          bill: { businessId, date: { gte: start, lte: end } },
        },
        include: { item: { select: { name: true } } },
      });

      const itemAgg = new Map<string, { name: string; quantity: number; revenue: number }>();
      for (const bi of billItems) {
        const existing = itemAgg.get(bi.itemId) ?? {
          name: (bi as any).item?.name ?? bi.itemId,
          quantity: 0,
          revenue: 0,
        };
        existing.quantity += bi.quantity;
        existing.revenue += bi.lineTotal as number;
        itemAgg.set(bi.itemId, existing);
      }

      const sorted = Array.from(itemAgg.entries())
        .map(([id, data]) => ({ id, ...data }))
        .sort((a, b) =>
          sortBy === 'quantity'
            ? b.quantity - a.quantity
            : b.revenue - a.revenue,
        )
        .slice(0, limit);

      return sorted;
    }

    case 'getAlerts': {
      const status = (args.status as string) || 'ACTIVE';
      const where: Record<string, unknown> = { businessId };
      if (status !== 'ALL') {
        where.status = status;
      }

      const alerts = await prisma.alert.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 50,
      });

      return alerts;
    }

    case 'getSalaryDetails': {
      const userId = args.userId as string | undefined;
      const monthStr = args.month as string | undefined;

      const where: Record<string, unknown> = { businessId };
      if (userId) where.operatorId = userId;

      if (monthStr) {
        const [year, month] = monthStr.split('-').map(Number);
        const start = new Date(year, month - 1, 1);
        const end = new Date(year, month, 0, 23, 59, 59, 999);
        where.createdAt = { gte: start, lte: end };
      }

      const salaries = await prisma.salaryRecord.findMany({
        where,
        include: { operator: { select: { name: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
      });

      return salaries.map((s) => ({
        operatorId: s.operatorId,
        operatorName: (s as any).operator?.name ?? 'Unknown',
        baseSalary: s.baseSalary,
        totalDeductions: s.totalLossDed + s.totalCashShort + s.totalAdvanceDed,
        netSalary: s.netSalary,
        createdAt: s.createdAt,
      }));
    }

    case 'getPurchasePriceHistory': {
      const itemId = args.itemId as string | undefined;
      const days = (args.days as number) || 30;

      const since = new Date();
      since.setDate(since.getDate() - days);

      const where: Record<string, unknown> = { businessId, createdAt: { gte: since } };

      const purchases = await prisma.purchase.findMany({
        where,
        include: {
          items: {
            where: itemId ? { itemId } : undefined,
            include: { item: { select: { name: true } } },
          },
          supplier: { select: { name: true } },
        },
        orderBy: { createdAt: 'desc' },
      });

      const priceHistory: Array<{
        itemId: string;
        itemName: string;
        supplierName: string;
        unitPrice: number;
        quantity: number;
        date: Date;
      }> = [];

      for (const p of purchases) {
        for (const pi of p.items) {
          priceHistory.push({
            itemId: pi.itemId,
            itemName: (pi as any).item?.name ?? pi.itemId,
            supplierName: (p as any).supplier?.name ?? 'Unknown',
            unitPrice: pi.unitPrice as number,
            quantity: pi.quantity,
            date: p.createdAt,
          });
        }
      }

      return priceHistory;
    }

    case 'getCustomerStats': {
      const startDate = args.startDate as string | undefined;
      const endDate = args.endDate as string | undefined;
      const limit = (args.limit as number) || 10;

      const totalCustomers = await prisma.customer.count({ where: { businessId } });

      const dateFilter: Record<string, unknown> = {};
      if (startDate) dateFilter.gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        dateFilter.lte = end;
      }

      const billWhere: Record<string, unknown> = {
        businessId,
        customerPhone: { not: null },
      };
      if (Object.keys(dateFilter).length > 0) billWhere.date = dateFilter;

      const bills = await prisma.bill.findMany({
        where: billWhere,
        select: { customerPhone: true, total: true },
      });

      // Customer spend aggregation
      const customerSpend = new Map<string, { bills: number; total: number }>();
      for (const b of bills) {
        if (!b.customerPhone) continue;
        const existing = customerSpend.get(b.customerPhone) ?? { bills: 0, total: 0 };
        existing.bills += 1;
        existing.total += b.total as number;
        customerSpend.set(b.customerPhone, existing);
      }

      const repeatCustomers = Array.from(customerSpend.values()).filter(
        (c) => c.bills > 1,
      ).length;

      const topCustomers = Array.from(customerSpend.entries())
        .map(([phone, data]) => ({ phone, ...data }))
        .sort((a, b) => b.total - a.total)
        .slice(0, limit);

      return {
        totalCustomers,
        activeCustomers: customerSpend.size,
        repeatCustomers,
        repeatRate:
          customerSpend.size > 0
            ? Math.round((repeatCustomers / customerSpend.size) * 100)
            : 0,
        topCustomers,
      };
    }

    default:
      return { error: `Unknown tool: ${name}` };
  }
}
