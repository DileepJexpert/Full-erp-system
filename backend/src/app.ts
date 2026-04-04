import Fastify from 'fastify';
import { ZodError } from 'zod';
import { registerSwagger } from './plugins/swagger.js';
import { registerCors } from './plugins/cors.js';
import { registerAuth } from './plugins/auth.js';
import { registerTenant } from './plugins/tenant.js';
import { registerRateLimit } from './middleware/rateLimit.js';
import { AppError } from './utils/errors.js';
import { API_PREFIX } from './config/constants.js';

// Route imports
import { authRoutes } from './modules/auth/auth.routes.js';
import { configRoutes } from './modules/config/config.routes.js';
import { inventoryRoutes } from './modules/inventory/inventory.routes.js';
import { dispatchRoutes } from './modules/dispatch/dispatch.routes.js';
import { billingRoutes } from './modules/billing/billing.routes.js';
import { reconciliationRoutes } from './modules/reconciliation/reconciliation.routes.js';
import { cashRoutes } from './modules/cash/cash.routes.js';
import { attendanceRoutes } from './modules/attendance/attendance.routes.js';
import { salaryRoutes } from './modules/salary/salary.routes.js';
import { expensesRoutes as expenseRoutes } from './modules/expenses/expenses.routes.js';
import { suppliersRoutes as supplierRoutes } from './modules/suppliers/suppliers.routes.js';
import { purchasesRoutes as purchaseRoutes } from './modules/purchases/purchases.routes.js';
import { alertRoutes } from './modules/alerts/alerts.routes.js';
import { performanceRoutes } from './modules/performance/performance.routes.js';
import { loyaltyRoutes } from './modules/loyalty/loyalty.routes.js';
import { complianceRoutes } from './modules/compliance/compliance.routes.js';
import { dashboardRoutes } from './modules/dashboard/dashboard.routes.js';
import { reportRoutes } from './modules/reports/reports.routes.js';
import { templateRoutes } from './modules/templates/templates.routes.js';
import { weatherRoutes } from './modules/weather/weather.routes.js';
import { paymentRoutes } from './modules/payments/payments.routes.js';
import { webhookRoutes } from './modules/webhooks/razorpay.routes.js';
import { locationsRoutes as locationRoutes } from './modules/locations/locations.routes.js';

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
      transport: process.env.NODE_ENV !== 'production'
        ? { target: 'pino-pretty', options: { colorize: true } }
        : undefined,
    },
  });

  // Global error handler
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({
        error: error.message,
        code: error.code,
        details: error.details,
      });
    }

    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: error.flatten(),
      });
    }

    // Fastify validation errors
    if (error.validation) {
      return reply.status(400).send({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: error.validation,
      });
    }

    app.log.error(error);
    return reply.status(500).send({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
    });
  });

  // Register plugins
  await registerCors(app);
  await registerSwagger(app);
  await registerAuth(app);
  await registerTenant(app);
  await registerRateLimit(app);

  // Health check
  app.get('/health', { schema: { tags: ['Health'] } }, async () => ({
    status: 'ok',
    timestamp: new Date().toISOString(),
  }));

  // Register route modules under API prefix
  await app.register(async (api) => {
    await api.register(authRoutes);
    await api.register(configRoutes);
    await api.register(locationRoutes);
    await api.register(inventoryRoutes);
    await api.register(dispatchRoutes);
    await api.register(billingRoutes);
    await api.register(reconciliationRoutes);
    await api.register(cashRoutes);
    await api.register(attendanceRoutes);
    await api.register(salaryRoutes);
    await api.register(expenseRoutes);
    await api.register(supplierRoutes);
    await api.register(purchaseRoutes);
    await api.register(alertRoutes);
    await api.register(performanceRoutes);
    await api.register(loyaltyRoutes);
    await api.register(complianceRoutes);
    await api.register(dashboardRoutes);
    await api.register(reportRoutes);
    await api.register(templateRoutes);
    await api.register(weatherRoutes);
    await api.register(paymentRoutes);
    await api.register(webhookRoutes);
  }, { prefix: API_PREFIX });

  return app;
}
