import { Module } from '@nestjs/common';
import { AgentPacksController } from './agent-packs.controller';
import { AgentPacksService } from './agent-packs.service';

@Module({
  controllers: [AgentPacksController],
  providers: [AgentPacksService],
  exports: [AgentPacksService],
})
export class AgentPacksModule {}
