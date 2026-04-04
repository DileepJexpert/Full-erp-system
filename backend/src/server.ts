import { buildApp } from './app.js';
import { getEnv } from './config/env.js';

async function start() {
  const env = getEnv();
  const app = await buildApp();

  try {
    await app.listen({ port: env.PORT, host: '0.0.0.0' });
    console.log(`Server running at http://localhost:${env.PORT}`);
    console.log(`API docs at http://localhost:${env.PORT}/docs`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

start();
