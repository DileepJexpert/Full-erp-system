import Redis from 'ioredis';
import { getEnv } from '../config/env.js';

let _redis: Redis | null = null;

export function getRedis(): Redis {
  if (!_redis) {
    const env = getEnv();
    _redis = new Redis(env.REDIS_URL, {
      maxRetriesPerRequest: 3,
      lazyConnect: true,
    });
    _redis.on('error', (err) => {
      console.error('Redis connection error:', err.message);
    });
  }
  return _redis;
}

export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    const data = await getRedis().get(key);
    return data ? JSON.parse(data) : null;
  } catch {
    return null;
  }
}

export async function cacheSet(key: string, value: unknown, ttlSeconds = 300): Promise<void> {
  try {
    await getRedis().set(key, JSON.stringify(value), 'EX', ttlSeconds);
  } catch {
    // Cache write failure is non-critical
  }
}

export async function cacheDelete(pattern: string): Promise<void> {
  try {
    const redis = getRedis();
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  } catch {
    // Cache delete failure is non-critical
  }
}
