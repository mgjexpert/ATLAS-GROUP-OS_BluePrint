import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type Tenant } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import type {
  ActionEnvelope,
  PolicyDecision,
} from './action-envelope.types';
import { PolicyEngineService } from '../policy/policy-engine.service';
import { ToolRegistryService } from '../tools/tool-registry.service';
import { ToolRunnerService } from '../tools/tool-runner.service';
import type { RuntimeActor } from '../runtime.types';

@Injectable()
export class RuntimeActionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: ToolRegistryService,
    private readonly policy: PolicyEngineService,
    private readonly runner: ToolRunnerService,
  ) {}

  async proposeAndExecute(
    tenant: Tenant,
    runId: string,
    toolCode: string,
    input: unknown,
    initiatedBy: RuntimeActor,
  ) {
    const run = await this.prisma.runtimeRun.findFirst({
      where: {
        id: runId,
        tenantId: tenant.id,
      },
    });

    if (!run) {
      throw new NotFoundException('Run não encontrado.');
    }

    const tool = this.registry.resolve(toolCode);
    const validatedInput = tool.validate(input);
    const ordinal = await this.nextOrdinal(run.id);

    const proposalStep = await this.prisma.runtimeStep.create({
      data: {
        runId: run.id,
        ordinal,
        kind: 'tool_proposal',
        status: 'completed',
        toolCode: tool.definition.code,
        inputSummary: {
          toolCode: tool.definition.code,
          input: validatedInput,
        } as Prisma.InputJsonValue,
        completedAt: new Date(),
      },
    });

    const envelope: ActionEnvelope = {
      id: randomUUID(),
      runId: run.id,
      stepId: proposalStep.id,
      tool: tool.definition.code,
      toolVersion: tool.definition.version,
      capability: tool.definition.capability,
      input: validatedInput,
      sideEffect: tool.definition.sideEffect,
      risk: tool.definition.defaultRisk,
      requestedBy: {
        agentId: run.agentId,
        agentVersionId: run.agentVersionId,
      },
      target: {
        organizationId: run.organizationId,
        tenantId: run.tenantId,
      },
      approval: {
        required: tool.definition.sideEffect !== 'none',
        policyIds: [],
      },
      timeoutMs: tool.definition.timeoutMs,
    };

    const action = await this.prisma.runtimeAction.create({
      data: {
        id: envelope.id,
        runId: run.id,
        stepId: proposalStep.id,
        toolCode: envelope.tool,
        toolVersion: envelope.toolVersion,
        capability: envelope.capability,
        input: envelope.input as Prisma.InputJsonValue,
        sideEffect: envelope.sideEffect,
        risk: envelope.risk,
        status: 'proposed',
      },
    });

    await this.event(
      run.id,
      run.traceId,
      'tool.proposed',
      initiatedBy,
      {
        actionId: action.id,
        toolCode: envelope.tool,
        capability: envelope.capability,
        sideEffect: envelope.sideEffect,
        risk: envelope.risk,
      },
    );

    const policyDecision =
      await this.policy.evaluate(envelope);

    await this.recordPolicy(
      run.id,
      envelope,
      policyDecision,
    );

    if (policyDecision.result === 'deny') {
      await this.prisma.runtimeAction.update({
        where: { id: action.id },
        data: {
          policyResult: 'deny',
          policyReason: policyDecision.reason,
          status: 'denied',
          finishedAt: new Date(),
        },
      });

      throw new ForbiddenException(policyDecision.reason);
    }

    if (policyDecision.result === 'approval_required') {
      await this.prisma.runtimeAction.update({
        where: { id: action.id },
        data: {
          policyResult: 'approval_required',
          policyReason: policyDecision.reason,
          status: 'suspended',
        },
      });

      return {
        actionId: action.id,
        status: 'suspended',
        policy: policyDecision,
      };
    }

    await this.prisma.runtimeAction.update({
      where: { id: action.id },
      data: {
        policyResult: 'allow',
        status: 'allowed',
      },
    });

    const executionOrdinal = await this.nextOrdinal(run.id);
    const executionStep = await this.prisma.runtimeStep.create({
      data: {
        runId: run.id,
        ordinal: executionOrdinal,
        kind: 'tool_execution',
        status: 'running',
        toolCode: envelope.tool,
        inputSummary: {
          actionId: action.id,
          toolCode: envelope.tool,
        } as Prisma.InputJsonValue,
      },
    });

    const started = Date.now();

    await this.prisma.runtimeAction.update({
      where: { id: action.id },
      data: {
        status: 'running',
        startedAt: new Date(),
      },
    });

    await this.event(
      run.id,
      run.traceId,
      'tool.started',
      initiatedBy,
      {
        actionId: action.id,
        stepId: executionStep.id,
        toolCode: envelope.tool,
      },
    );

    try {
      const result = await this.runner.execute(
        envelope,
        {
          organizationId: run.organizationId,
          tenantId: run.tenantId,
          agentId: run.agentId,
          runId: run.id,
          traceId: run.traceId,
        },
        policyDecision,
      );

      const output = this.toJson(result);

      await this.prisma.$transaction([
        this.prisma.runtimeStep.update({
          where: { id: executionStep.id },
          data: {
            status: 'completed',
            outputSummary: {
              actionId: action.id,
              output,
            } as Prisma.InputJsonValue,
            latencyMs: Date.now() - started,
            completedAt: new Date(),
          },
        }),
        this.prisma.runtimeAction.update({
          where: { id: action.id },
          data: {
            status: 'completed',
            output,
            finishedAt: new Date(),
          },
        }),
      ]);

      await this.event(
        run.id,
        run.traceId,
        'tool.completed',
        initiatedBy,
        {
          actionId: action.id,
          stepId: executionStep.id,
          toolCode: envelope.tool,
          latencyMs: Date.now() - started,
        },
      );

      return {
        actionId: action.id,
        status: 'completed',
        policy: policyDecision,
        output: result,
      };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : String(error);

      await this.prisma.$transaction([
        this.prisma.runtimeStep.update({
          where: { id: executionStep.id },
          data: {
            status: 'failed',
            errorMessage: message,
            latencyMs: Date.now() - started,
            completedAt: new Date(),
          },
        }),
        this.prisma.runtimeAction.update({
          where: { id: action.id },
          data: {
            status: 'failed',
            errorMessage: message,
            finishedAt: new Date(),
          },
        }),
      ]);

      await this.event(
        run.id,
        run.traceId,
        'tool.failed',
        initiatedBy,
        {
          actionId: action.id,
          stepId: executionStep.id,
          toolCode: envelope.tool,
          error: message,
        },
      );

      throw error;
    }
  }

  private async recordPolicy(
    runId: string,
    envelope: ActionEnvelope,
    decision: PolicyDecision,
  ) {
    const ordinal = await this.nextOrdinal(runId);

    await this.prisma.runtimeStep.create({
      data: {
        runId,
        ordinal,
        kind: 'policy',
        status: 'completed',
        toolCode: envelope.tool,
        inputSummary: {
          actionId: envelope.id,
          toolCode: envelope.tool,
          sideEffect: envelope.sideEffect,
          risk: envelope.risk,
        } as Prisma.InputJsonValue,
        outputSummary: {
          decision: decision.result,
          policyIds: decision.policyIds,
          ...('reason' in decision
            ? { reason: decision.reason }
            : {}),
        } as Prisma.InputJsonValue,
        completedAt: new Date(),
      },
    });
  }

  private async nextOrdinal(runId: string): Promise<number> {
    const max = await this.prisma.runtimeStep.aggregate({
      where: { runId },
      _max: { ordinal: true },
    });
    return (max._max.ordinal ?? 0) + 1;
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

  private toJson(value: unknown): Prisma.InputJsonValue {
    return JSON.parse(
      JSON.stringify(value ?? null),
    ) as Prisma.InputJsonValue;
  }
}
