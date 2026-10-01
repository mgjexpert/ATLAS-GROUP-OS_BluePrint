import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import type {
  ActionEnvelope,
  PolicyDecision,
} from '../actions/action-envelope.types';
import { ToolRegistryService } from '../tools/tool-registry.service';

type PolicyEvaluationOptions = {
  approvalRequestId?: string;
};

@Injectable()
export class PolicyEngineService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: ToolRegistryService,
  ) {}

  async evaluate(
    envelope: ActionEnvelope,
    options: PolicyEvaluationOptions = {},
  ): Promise<PolicyDecision> {
    const tool = this.registry.resolve(envelope.tool);

    if (
      tool.definition.version !== envelope.toolVersion ||
      tool.definition.capability !== envelope.capability ||
      tool.definition.sideEffect !== envelope.sideEffect ||
      tool.definition.defaultRisk !== envelope.risk
    ) {
      return {
        result: 'deny',
        policyIds: ['tool.definition.integrity'],
        reason:
          'ActionEnvelope no longer matches the registered tool definition.',
      };
    }

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
        reason:
          'Agent does not have an active grant for this tool.',
      };
    }

    if (envelope.sideEffect === 'none') {
      return {
        result: 'allow',
        policyIds: [
          'tool.registered.enabled',
          'tool.grant.required',
          'tool.read_only.allowed',
        ],
      };
    }

    if (!envelope.target.organizationId) {
      return {
        result: 'deny',
        policyIds: ['organization.required_for_side_effect'],
        reason:
          'Side-effect actions require an Organization context.',
      };
    }

    if (!options.approvalRequestId) {
      return {
        result: 'approval_required',
        policyIds: [
          'tool.registered.enabled',
          'tool.grant.required',
          'tool.side_effect.approval',
        ],
        reason:
          'Side-effect action requires durable human approval.',
      };
    }

    const approval =
      await this.prisma.approvalRequest.findFirst({
        where: {
          id: options.approvalRequestId,
          organizationId: envelope.target.organizationId,
          tenantId: envelope.target.tenantId,
          runId: envelope.runId,
          actionId: envelope.id,
          status: 'approved',
        },
      });

    if (!approval) {
      return {
        result: 'deny',
        policyIds: ['approval.approved.required'],
        reason:
          'Approved request does not match this action/run/tenant.',
      };
    }

    if (
      approval.expiresAt &&
      approval.expiresAt.getTime() <= Date.now()
    ) {
      return {
        result: 'deny',
        policyIds: ['approval.not_expired'],
        reason: 'Approval has expired.',
      };
    }

    const decision =
      await this.prisma.approvalDecision.findFirst({
        where: {
          approvalRequestId: approval.id,
          decision: 'approved',
        },
      });

    if (!decision) {
      return {
        result: 'deny',
        policyIds: ['approval.decision.persisted'],
        reason:
          'No persisted approved decision exists for this request.',
      };
    }

    return {
      result: 'allow',
      policyIds: [
        'tool.registered.enabled',
        'tool.grant.required',
        'tool.side_effect.approval',
        'approval.approved.required',
        'approval.decision.persisted',
        'approval.not_expired',
      ],
    };
  }
}
