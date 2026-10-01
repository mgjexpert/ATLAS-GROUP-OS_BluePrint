import {
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { PortfolioUpdateTaskStatusTool } from './builtin/portfolio-update-task-status.tool';
import { RuntimeInspectRunTool } from './builtin/runtime-inspect-run.tool';
import type {
  RuntimeTool,
  RuntimeToolDefinition,
} from './tool.types';

@Injectable()
export class ToolRegistryService implements OnModuleInit {
  private readonly tools: Map<string, RuntimeTool>;

  constructor(
    private readonly prisma: PrismaService,
    inspectRun: RuntimeInspectRunTool,
    updateTaskStatus: PortfolioUpdateTaskStatusTool,
  ) {
    this.tools = new Map([
      [inspectRun.definition.code, inspectRun],
      [
        updateTaskStatus.definition.code,
        updateTaskStatus,
      ],
    ]);
  }

  async onModuleInit(): Promise<void> {
    for (const tool of this.tools.values()) {
      const definition = tool.definition;

      await this.prisma.toolDefinitionRecord.upsert({
        where: {
          code_version: {
            code: definition.code,
            version: definition.version,
          },
        },
        create: {
          code: definition.code,
          version: definition.version,
          description: definition.description,
          capability: definition.capability,
          inputSchema:
            definition.inputSchema as Prisma.InputJsonValue,
          outputSchema:
            (definition.outputSchema ??
              undefined) as Prisma.InputJsonValue | undefined,
          sideEffect: definition.sideEffect,
          defaultRisk: definition.defaultRisk,
          enabled: true,
          timeoutMs: definition.timeoutMs,
        },
        update: {
          description: definition.description,
          capability: definition.capability,
          inputSchema:
            definition.inputSchema as Prisma.InputJsonValue,
          outputSchema:
            (definition.outputSchema ??
              undefined) as Prisma.InputJsonValue | undefined,
          sideEffect: definition.sideEffect,
          defaultRisk: definition.defaultRisk,
          timeoutMs: definition.timeoutMs,
        },
      });
    }
  }

  resolve(code: string): RuntimeTool {
    const tool = this.tools.get(code);
    if (!tool) {
      throw new NotFoundException(
        `Tool não registrado: ${code}`,
      );
    }
    return tool;
  }

  list(): RuntimeToolDefinition[] {
    return Array.from(this.tools.values()).map(
      (tool) => tool.definition,
    );
  }

  async listGranted(
    tenantId: string,
    agentId: string,
  ): Promise<RuntimeToolDefinition[]> {
    const grants = await this.prisma.toolGrant.findMany({
      where: {
        tenantId,
        agentId,
        status: 'active',
      },
      select: {
        toolCode: true,
      },
    });

    const grantedCodes = Array.from(
      new Set(grants.map((grant) => grant.toolCode)),
    );

    if (!grantedCodes.length) {
      return [];
    }

    const persisted =
      await this.prisma.toolDefinitionRecord.findMany({
        where: {
          code: { in: grantedCodes },
          enabled: true,
        },
      });

    const persistedKey = new Set(
      persisted.map(
        (item) => `${item.code}@${item.version}`,
      ),
    );

    const definitions: RuntimeToolDefinition[] = [];

    for (const code of grantedCodes) {
      const tool = this.tools.get(code);
      if (!tool) continue;

      const definition = tool.definition;
      if (
        !persistedKey.has(
          `${definition.code}@${definition.version}`,
        )
      ) {
        continue;
      }

      definitions.push(definition);
    }

    return definitions.sort((a, b) =>
      a.code.localeCompare(b.code),
    );
  }
}
