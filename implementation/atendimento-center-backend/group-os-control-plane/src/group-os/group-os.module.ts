import { Module } from '@nestjs/common';
import { GroupOsController } from './group-os.controller';
import { GroupOsService } from './group-os.service';

@Module({
  controllers: [GroupOsController],
  providers: [GroupOsService],
  exports: [GroupOsService],
})
export class GroupOsModule {}
