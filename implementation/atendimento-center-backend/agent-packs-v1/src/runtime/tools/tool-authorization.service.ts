import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class ToolAuthorizationService {
  constructor(private readonly prisma: PrismaService) {}

  async authorizedToolCodes(
    tenantId: string,
    agentId: string,
  ): Promise<string[]> {
    const explicit = await this.prisma.toolGrant.findMany({
      where: {
        tenantId,
        agentId,
        status: 'active',
      },
      select: { toolCode: true },
    });

    const codes = new Set(
      explicit.map((item) => item.toolCode),
    );

    const assignment =
      await this.prisma.agentPackAssignment.findFirst({
        where: {
          tenantId,
          agentId,
          status: 'active',
        },
      });

    if (!assignment) {
      return Array.from(codes).sort();
    }

    const version =
      await this.prisma.agentPackVersion.findFirst({
        where: {
          id: assignment.packVersionId,
          status: 'approved',
        },
      });

    if (!version) {
      return Array.from(codes).sort();
    }

    const packTools =
      await this.prisma.agentPackTool.findMany({
        where: {
          packVersionId: version.id,
          mode: 'allowed',
        },
        select: { toolCode: true },
      });

    for (const item of packTools) {
      codes.add(item.toolCode);
    }

    return Array.from(codes).sort();
  }

  async isAuthorized(
    tenantId: string,
    agentId: string,
    toolCode: string,
  ): Promise<boolean> {
    const codes = await this.authorizedToolCodes(
      tenantId,
      agentId,
    );

    return codes.includes(toolCode);
  }
}
