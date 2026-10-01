import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import type {
  ActionEnvelope,
  PolicyDecision,
} from '../actions/action-envelope.types';
import { ToolAuthorizationService } from '../tools/tool-authorization.service';
import { ToolRegistryService } from '../tools/tool-registry.service';

@Injectable()
export class PolicyEngineService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: ToolRegistryService,
    private readonly authorization: ToolAuthorizationService,
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

    const authorized =
      await this.authorization.isAuthorized(
        envelope.target.tenantId,
        envelope.requestedBy.agentId,
        envelope.tool,
      );

    if (!authorized) {
      return {
        result: 'deny',
        policyIds: ['tool.authorization.required'],
        reason:
          'Agent does not have an active manual grant or approved Agent Pack authorization for this tool.',
      };
    }

    if (envelope.sideEffect !== 'none') {
      return {
        result: 'approval_required',
        policyIds: ['tool.side_effect.approval'],
        reason:
          'Side-effect tools require durable approval before execution.',
      };
    }

    return {
      result: 'allow',
      policyIds: [
        'tool.registered.enabled',
        'tool.authorization.required',
        'tool.read_only.allowed',
      ],
    };
  }
}
