import type { FastifyRequest, FastifyReply } from 'fastify';
import { ForbiddenError } from '../utils/errors.js';

type Role = 'OWNER' | 'MANAGER' | 'STAFF';

const ROLE_HIERARCHY: Record<Role, number> = {
  OWNER: 3,
  MANAGER: 2,
  STAFF: 1,
};

export function authorize(...allowedRoles: Role[]) {
  return async (request: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    const userRole = request.tenant?.role;
    if (!userRole) {
      throw new ForbiddenError('No role assigned');
    }

    // Owner can access everything
    if (userRole === 'OWNER') return;

    if (!allowedRoles.includes(userRole)) {
      throw new ForbiddenError(`Role '${userRole}' is not authorized for this action`);
    }
  };
}

export function requireMinRole(minRole: Role) {
  return async (request: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    const userRole = request.tenant?.role;
    if (!userRole) {
      throw new ForbiddenError('No role assigned');
    }

    if (ROLE_HIERARCHY[userRole] < ROLE_HIERARCHY[minRole]) {
      throw new ForbiddenError(`Minimum role '${minRole}' required`);
    }
  };
}
