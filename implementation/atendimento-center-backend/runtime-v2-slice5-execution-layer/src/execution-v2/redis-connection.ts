import { ConfigService } from '@nestjs/config';
import IORedis from 'ioredis';

export function createAtlasRedis(
  config: ConfigService,
): IORedis {
  const url = config.get<string>('ATLAS_REDIS_URL')?.trim();

  if (!url) {
    throw new Error('ATLAS_REDIS_URL is not configured');
  }

  return new IORedis(url, {
    maxRetriesPerRequest: null,
    enableReadyCheck: true,
    lazyConnect: false,
  });
}
