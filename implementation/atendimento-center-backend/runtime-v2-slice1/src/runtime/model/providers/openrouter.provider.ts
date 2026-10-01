import { HttpService } from '@nestjs/axios';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import type { ModelProvider } from '../model-provider.interface';
import type {
  ModelCapability,
  ProviderModelRequest,
  ProviderModelResponse,
} from '../model.types';

type OpenRouterCompletionResponse = {
  model?: string;
  provider?: string;
  choices?: Array<{
    finish_reason?: string | null;
    message?: {
      content?: string | null;
    };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
    cost?: number | string | null;
  };
};

@Injectable()
export class OpenRouterProvider implements ModelProvider {
  readonly id = 'openrouter';

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {}

  supports(capability: ModelCapability): boolean {
    return capability === 'text';
  }

  async generate(
    request: ProviderModelRequest,
  ): Promise<ProviderModelResponse> {
    const apiKey = this.config.get<string>('OPENROUTER_API_KEY');
    if (!apiKey) {
      throw new Error('OPENROUTER_API_KEY is not configured');
    }

    const model =
      request.model ??
      this.config.get<string>('OPENROUTER_MODEL') ??
      'openai/gpt-4.1-mini';

    const started = Date.now();
    const response = await firstValueFrom(
      this.http.post<OpenRouterCompletionResponse>(
        'https://openrouter.ai/api/v1/chat/completions',
        {
          model,
          messages: request.messages,
          temperature: request.temperature ?? 0.2,
          ...(request.maxTokens ? { max_tokens: request.maxTokens } : {}),
        },
        {
          headers: {
            Authorization: 'Bearer ' + apiKey,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://atendimento.center',
            'X-Title': 'Atlas Intelligence Runtime',
          },
        },
      ),
    );

    const usage = response.data.usage ?? {};
    const inputTokens = Number(usage.prompt_tokens ?? 0);
    const outputTokens = Number(usage.completion_tokens ?? 0);
    const rawCost = usage.cost;
    const parsedCost =
      rawCost === null || rawCost === undefined ? null : Number(rawCost);

    return {
      provider: this.id,
      model: response.data.model ?? model,
      content: response.data.choices?.[0]?.message?.content ?? '',
      stopReason: response.data.choices?.[0]?.finish_reason ?? null,
      usage: {
        inputTokens,
        outputTokens,
        totalTokens: Number(
          usage.total_tokens ?? inputTokens + outputTokens,
        ),
        costUsd:
          parsedCost !== null && Number.isFinite(parsedCost)
            ? parsedCost
            : null,
      },
      latencyMs: Date.now() - started,
    };
  }
}
