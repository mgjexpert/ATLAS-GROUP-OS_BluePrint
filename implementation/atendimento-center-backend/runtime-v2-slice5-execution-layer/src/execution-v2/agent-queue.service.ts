import {
  Injectable,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  Prisma,
  type Tenant,
} from '@prisma/client';
import { Queue } from 'bullmq';
import { PrismaService } from '../database/prisma.service';
import type { RuntimeActor } from '../runtime/runtime.types';
import { ATLAS_QUEUES } from './queue-names';
import { createAtlasRedis } from './redis-connection';
import type { EnqueueRuntimeRunDto } from './execution.dto';

type AgentQueuePayload = {
  executionJobId: string;
};

@Injectable()
export class AgentQueueService
  implements OnModuleDestroy
{
  private readonly queue: Queue<AgentQueuePayload>;
  private readonly connection;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.connection = createAtlasRedis(config);
    this.queue = new Queue<AgentQueuePayload>(
      ATLAS_QUEUES.agent,
      {
        connection: this.connection,
        defaultJobOptions: {
          removeOnComplete: 100,
          removeOnFail: 500,
        },
      },
    );
  }

  async enqueue(
    tenant: Tenant,
    actor: RuntimeActor,
    body: EnqueueRuntimeRunDto,
  ) {
    const execution =
      await this.prisma.executionJob.create({
        data: {
          tenantId: tenant.id,
          queueName: ATLAS_QUEUES.agent,
          jobType: 'runtime.start',
          actorType: actor.type,
          actorId: actor.id,
          status: 'queued',
          maxAttempts: 1,
          request: {
            agentCode: body.agentCode,
            input: body.input,
            model: body.model ?? null,
            metadata: body.metadata ?? {},
          } as Prisma.InputJsonValue,
          metadata: {
            source: 'runtime-api',
          } as Prisma.InputJsonValue,
        },
      });

    try {
      const job = await this.queue.add(
        'runtime.start',
        {
          executionJobId: execution.id,
        },
        {
          jobId: execution.id,
          attempts: execution.maxAttempts,
        },
      );

      return {
        executionJobId: execution.id,
        queue: ATLAS_QUEUES.agent,
        bullJobId: String(job.id),
        status: execution.status,
      };
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);

      await this.prisma.executionJob.update({
        where: { id: execution.id },
        data: {
          status: 'failed',
          errorMessage: message,
          finishedAt: new Date(),
        },
      });

      throw error;
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.queue.close();
    await this.connection.quit();
  }
}
