import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { Tenant } from '@prisma/client';
import {
  CurrentTenant,
  TenantRoles,
} from '../../auth/auth.decorators';
import {
  SupabaseAuthGuard,
  TenantGuard,
  TenantRoleGuard,
} from '../../auth/auth.guards';
import { PrismaService } from '../../database/prisma.service';
import { RuntimeActionService } from '../actions/runtime-action.service';
import {
  ExecuteRuntimeToolDto,
  GrantRuntimeToolDto,
} from './runtime-tools.dto';
import { ToolRegistryService } from './tool-registry.service';

@Controller('runtime')
@UseGuards(
  SupabaseAuthGuard,
  TenantGuard,
  TenantRoleGuard,
)
export class RuntimeToolsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: ToolRegistryService,
    private readonly actions: RuntimeActionService,
  ) {}

  @Get('tools')
  listTools() {
    return this.registry.list();
  }

  @Post('tool-grants')
  @TenantRoles('owner', 'admin')
  async grant(
    @CurrentTenant() tenant: Tenant,
    @Body() body: GrantRuntimeToolDto,
  ) {
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

    const tool = this.registry.resolve(body.toolCode);

    return this.prisma.toolGrant.upsert({
      where: {
        tenantId_agentId_toolCode: {
          tenantId: tenant.id,
          agentId: agent.id,
          toolCode: tool.definition.code,
        },
      },
      create: {
        tenantId: tenant.id,
        agentId: agent.id,
        toolCode: tool.definition.code,
        status: 'active',
      },
      update: {
        status: 'active',
      },
    });
  }

  @Post('runs/:runId/actions')
  @TenantRoles('owner', 'admin', 'supervisor', 'agent')
  execute(
    @CurrentTenant() tenant: Tenant,
    @Param('runId') runId: string,
    @Body() body: ExecuteRuntimeToolDto,
  ) {
    return this.actions.proposeAndExecute(
      tenant,
      runId,
      body.toolCode,
      body.input,
    );
  }
}
