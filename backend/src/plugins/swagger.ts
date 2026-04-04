import type { FastifyInstance } from 'fastify';
import fastifySwagger from '@fastify/swagger';
import fastifySwaggerUi from '@fastify/swagger-ui';
import { APP_NAME, API_VERSION } from '../config/constants.js';

export async function registerSwagger(app: FastifyInstance): Promise<void> {
  await app.register(fastifySwagger, {
    openapi: {
      openapi: '3.1.0',
      info: {
        title: APP_NAME,
        description: 'Multi-tenant REST API for multi-vertical business operations',
        version: API_VERSION,
      },
      servers: [
        { url: 'http://localhost:3000', description: 'Development' },
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
          },
        },
      },
      security: [{ bearerAuth: [] }],
      tags: [
        { name: 'Auth', description: 'Phone OTP authentication' },
        { name: 'Config', description: 'Business configuration and feature flags' },
        { name: 'Locations', description: 'Location management' },
        { name: 'Inventory', description: 'Item and variant management' },
        { name: 'Dispatch', description: 'Daily dispatch to locations' },
        { name: 'Billing', description: 'POS billing with GST' },
        { name: 'Reconciliation', description: 'End-of-day reconciliation' },
        { name: 'Cash', description: 'Cash collection and tracking' },
        { name: 'Attendance', description: 'GPS-validated attendance' },
        { name: 'Salary', description: 'Monthly salary computation' },
        { name: 'Expenses', description: 'Location expense tracking' },
        { name: 'Suppliers', description: 'Supplier management' },
        { name: 'Purchases', description: 'Purchase orders and stock' },
        { name: 'Alerts', description: 'Alerts and anomaly detection' },
        { name: 'Performance', description: 'Operator performance scoring' },
        { name: 'Loyalty', description: 'Customer loyalty program' },
        { name: 'Compliance', description: 'Document compliance tracker' },
        { name: 'Dashboard', description: 'Owner dashboard stats' },
        { name: 'Reports', description: 'Business reports and exports' },
        { name: 'Templates', description: 'Menu and season templates' },
        { name: 'Weather', description: 'Weather data and correlation' },
        { name: 'Payments', description: 'Razorpay payment integration' },
        { name: 'Webhooks', description: 'Payment webhook handlers' },
      ],
    },
  });

  await app.register(fastifySwaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: true,
    },
  });
}
