export type ModelCapability =
  | 'text'
  | 'stream'
  | 'structured_output'
  | 'tools'
  | 'embeddings';

export type ModelMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string;
};

export type ModelUsage = {
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  costUsd: number | null;
};

export type ModelRequest = {
  provider?: string;
  model?: string;
  messages: ModelMessage[];
  temperature?: number;
  maxTokens?: number;
  metadata?: Record<string, unknown>;
};

export type ModelResponse = {
  provider: string;
  model: string;
  content: string;
  stopReason: string | null;
  usage: ModelUsage;
  latencyMs: number;
};

export type ProviderModelRequest = Omit<ModelRequest, 'provider'>;
export type ProviderModelResponse = ModelResponse;
