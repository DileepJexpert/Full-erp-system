import type { FastifyInstance } from 'fastify';
import * as weatherService from './weather.service.js';
import { authenticate } from '../../middleware/authenticate.js';

export async function weatherRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', authenticate);

  app.get('/weather', {
    schema: { tags: ['Weather'], summary: 'Get weather logs', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { locationId, days } = request.query as { locationId?: string; days?: string };
      const result = await weatherService.getWeatherLogs(
        request.tenant.businessId, locationId, days ? parseInt(days) : 7,
      );
      return reply.send(result);
    },
  });

  app.get('/weather/correlation/:locationId', {
    schema: { tags: ['Weather'], summary: 'Get weather-revenue correlation', security: [{ bearerAuth: [] }] },
    handler: async (request, reply) => {
      const { locationId } = request.params as { locationId: string };
      const { days } = request.query as { days?: string };
      const result = await weatherService.getWeatherCorrelation(
        request.tenant.businessId, locationId, days ? parseInt(days) : 30,
      );
      return reply.send(result);
    },
  });
}
