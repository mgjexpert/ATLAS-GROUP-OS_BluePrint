import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type Tenant } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { ModelGateway } from './model/model-gateway.service';
import type { StartRuntimeRunDto } from './runtime.dto';
import type {
  RuntimeActor,
  RuntimeRunResult,
} from './runtime.types';

@Injectable()
export class RuntimeRunService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly models: ModelGateway,
  ) {}

  async start(
    tenant: Tenant,
    actor: RuntimeActor,
    body: StartRuntimeRunDto,
  ): Promise<RuntimeRunResult> {
    const agent = await this.prisma.agent.findFirst({
      where: {
        tenantId: tenant.id,
        code: body.agentCode.trim().toLowerCase(),
        enabled: true,
      },
    });

    if (!agent) {
      throw new NotFoundException('Agente ativo não encontrado.');
    }

    const agentVersion = await this.prisma.agentVersion.findFirst({
      where: { agentId: agent.id },
      orderBy: { version: 'desc' },
    });

    const run = await this.prisma.runtimeRun.create({
      data: {
        organizationId: tenant.organizationId,
        tenantId: tenant.id,
        agentId: agent.id,
        agentVersionId: agentVersion?.id,
        actorType: actor.type,
        actorId: actor.id,
        triggerType: 'api',
        status: 'running',
        provider: agent.provider,
        model: body.model ?? agent.model,
        input: {
          inputChars: body.input.length,
        } as Prisma.InputJsonValue,
        metadata: (body.metadata ?? {}) as Prisma.InputJsonValue,
      },
    });

    await this.event(run.id, run.traceId, 'run.started', actor, {
      agentId: agent.id,
      agentVersionId: agentVersion?.id ?? null,
      provider: agent.provider,
      model: body.model ?? agent.model,
    });

    await this.prisma.runtimeStep.create({
      data: {
        runId: run.id,
        ordinal: 1,
        kind: 'context',
        status: 'completed',
        inputSummary: {
          tenantId: tenant.id,
          agentId: agent.id,
          agentVersionId: agentVersion?.id ?? null,
          inputChars: body.input.length,
        } as Prisma.InputJsonValue,
        outputSummary: {
          systemPromptChars: agent.systemPrompt.length,
        } as Prisma.InputJsonValue,
        completedAt: new Date(),
      },
    });

    const modelStep = await this.prisma.runtimeStep.create({
      data: {
        runId: run.id,
        ordinal: 2,
        kind: 'model',
        status: 'running',
        provider: agent.provider,
        model: body.model ?? agent.model,
        inputSummary: {
          messageCount: agent.systemPrompt ? 2 : 1,
          inputChars: body.input.length,
        } as Prisma.InputJsonValue,
      },
    });

    await this.event(run.id, run.traceId, 'step.started', actor, {
      stepId: modelStep.id,
      ordinal: 2,
      kind: 'model',
    });

    const started = Date.now();

    try {
      const response = await this.models.generate({
        provider: agent.provider,
        model: body.model ?? agent.model,
        messages: [
          ...(agent.systemPrompt
            ? [{ role: 'system' as const, content: agent.systemPrompt }]
            : []),
          { role: 'user', content: body.input },
        ],
        temperature:
          agent.temperature === null
            ? undefined
            : Number(agent.temperature),
        metadata: {
          runId: run.id,
          traceId: run.traceId,
          tenantId: tenant.id,
          agentId: agent.id,
        },
      });

      await this.prisma.$transaction([
        this.prisma.runtimeStep.update({
          where: { id: modelStep.id },
          data: {
            status: 'completed',
            provider: response.provider,
            model: response.model,
            outputSummary: {
              outputChars: response.content.length,
              stopReason: response.stopReason,
            } as Prisma.InputJsonValue,
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            costUsd: response.usage.costUsd,
            latencyMs: response.latencyMs,
            completedAt: new Date(),
          },
        }),
        this.prisma.runtimeStep.create({
          data: {
            runId: run.id,
            ordinal: 3,
            kind: 'response',
            status: 'completed',
            outputSummary: {
              outputChars: response.content.length,
            } as Prisma.InputJsonValue,
            completedAt: new Date(),
          },
        }),
        this.prisma.runtimeRun.update({
          where: { id: run.id },
          data: {
            status: 'completed',
            provider: response.provider,
            model: response.model,
            output: {
              content: response.content,
              stopReason: response.stopReason,
            } as Prisma.InputJsonValue,
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            costUsd: response.usage.costUsd,
            latencyMs: Date.now() - started,
            finishedAt: new Date(),
          },
        }),
      ]);

      await this.event(run.id, run.traceId, 'step.completed', actor, {
        stepId: modelStep.id,
        ordinal: 2,
        kind: 'model',
        provider: response.provider,
        model: response.model,
        inputTokens: response.usage.inputTokens,
        outputTokens: response.usage.outputTokens,
        costUsd: response.usage.costUsd,
      });

      await this.event(run.id, run.traceId, 'run.completed', actor, {
        provider: response.provider,
        model: response.model,
        latencyMs: Date.now() - started,
      });

      return {
        runId: run.id,
        traceId: run.traceId,
        status: 'completed',
        provider: response.provider,
        model: response.model,
        content: response.content,
        usage: response.usage,
        latencyMs: Date.now() - started,
      };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : String(error);

      await this.prisma.$transaction([
        this.prisma.runtimeStep.update({
          where: { id: modelStep.id },
          data: {
            status: 'failed',
            errorMessage: message,
            latencyMs: Date.now() - started,
            completedAt: new Date(),
          },
        }),
        this.prisma.runtimeRun.update({
          where: { id: run.id },
          data: {
            status: 'failed',
            errorMessage: message,
            latencyMs: Date.now() - started,
            finishedAt: new Date(),
          },
        }),
      ]);

      await this.event(run.id, run.traceId, 'run.failed', actor, {
        error: message,
      });

      throw error;
    }
  }

  private event(
    runId: string,
    traceId: string,
    eventType: string,
    actor: RuntimeActor,
    payload: Record<string, unknown>,
  ) {
    return this.prisma.runtimeEvent.create({
      data: {
        runId,
        traceId,
        eventType,
        actorType: actor.type,
        actorId: actor.id,
        payload: payload as Prisma.InputJsonValue,
      },
    });
  }
}
