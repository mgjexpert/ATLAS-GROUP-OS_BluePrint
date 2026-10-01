import { Module } from '@nestjs/common';
import { AgentQueueService } from './agent-queue.service';
import { ExecutionController } from './execution.controller';

@Module({
  controllers: [ExecutionController],
  providers: [AgentQueueService],
  exports: [AgentQueueService],
})
export class ExecutionModule {}
