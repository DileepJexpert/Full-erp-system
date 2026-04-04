import type { FastifyRequest, FastifyReply } from 'fastify';

export interface TenantContext {
  userId: string;
  businessId: string;
  role: 'OWNER' | 'MANAGER' | 'STAFF';
  phone: string;
}

export interface AuthenticatedRequest extends FastifyRequest {
  tenant: TenantContext;
}

export interface PaginationQuery {
  page?: number;
  limit?: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface ApiError {
  error: string;
  code: string;
  details?: unknown;
}

export interface DateRange {
  startDate: string;
  endDate: string;
}

declare module 'fastify' {
  interface FastifyRequest {
    tenant: TenantContext;
  }
}
