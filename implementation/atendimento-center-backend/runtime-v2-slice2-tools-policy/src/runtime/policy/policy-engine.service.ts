import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import type {
  ActionEnvelope,
  PolicyDecision,
} from '../actions/action-envelope.types';
import { ToolRegistryService } from '../tools/tool-registry.service';

@Injectable()
export class PolicyEngineService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: ToolRegistryService,
  ) {}

  async evaluate(
    envelope: ActionEnvelope,
  ): Promise<PolicyDecision> {
    const tool = this.registry.resolve(envelope.tool);

    const persistedDefinition =
      await this.prisma.toolDefinitionRecord.findFirst({
        where: {
          code: tool.definition.code,
          version: tool.definition.version,
          enabled: true,
        },
      });

    if (!persistedDefinition) {
      return {
        result: 'deny',
        policyIds: ['tool.registered.enabled'],
        reason: 'Tool definition is disabled or unavailable.',
      };
    }

    const grant = await this.prisma.toolGrant.findFirst({
      where: {
        tenantId: envelope.target.tenantId,
        agentId: envelope.requestedBy.agentId,
        toolCode: envelope.tool,
        status: 'active',
      },
    });

    if (!grant) {
      return {
        result: 'deny',
        policyIds: ['tool.grant.required'],
        reason: 'Agent does not have an active grant for this tool.',
      };
    }

    if (envelope.sideEffect !== 'none') {
      return {
        result: 'approval_required',
        policyIds: ['tool.side_effect.approval'],
        reason:
          'Slice 2 executes read-only tools only; side effects require ApprovalEngine.',
      };
    }

    return {
      result: 'allow',
      policyIds: [
        'tool.registered.enabled',
        'tool.grant.required',
        'tool.read_only.allowed',
      ],
    };
  }
}
