import { Injectable } from '@nestjs/common';
import type { ActionEnvelope } from '../actions/action-envelope.types';
import type { RuntimeToolContext } from './tool.types';
import { ToolRegistryService } from './tool-registry.service';

@Injectable()
export class ToolRunnerService {
  constructor(private readonly registry: ToolRegistryService) {}

  async execute(
    envelope: ActionEnvelope,
    context: RuntimeToolContext,
  ): Promise<unknown> {
    const tool = this.registry.resolve(envelope.tool);
    const input = tool.validate(envelope.input);

    let timeout: NodeJS.Timeout | undefined;

    try {
      const timeoutPromise = new Promise<never>((_resolve, reject) => {
        timeout = setTimeout(
          () => reject(new Error('Tool execution timed out')),
          envelope.timeoutMs,
        );
      });

      return await Promise.race([
        tool.execute(context, input),
        timeoutPromise,
      ]);
    } finally {
      if (timeout) clearTimeout(timeout);
    }
  }
}
