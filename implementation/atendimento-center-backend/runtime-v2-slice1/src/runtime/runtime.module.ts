import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { ModelGateway } from './model/model-gateway.service';
import { OpenRouterProvider } from './model/providers/openrouter.provider';
import { RuntimeController } from './runtime.controller';
import { RuntimeRunService } from './runtime-run.service';

@Module({
  imports: [
    HttpModule.register({
      timeout: 60000,
      maxRedirects: 3,
    }),
  ],
  controllers: [RuntimeController],
  providers: [
    OpenRouterProvider,
    ModelGateway,
    RuntimeRunService,
  ],
  exports: [
    ModelGateway,
    RuntimeRunService,
  ],
})
export class RuntimeModule {}
