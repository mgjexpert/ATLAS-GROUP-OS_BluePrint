export type RuntimeActor = {
  type: 'user' | 'service' | 'agent';
  id: string | null;
};

export type RuntimeRunResult = {
  runId: string;
  traceId: string;
  status: 'completed';
  provider: string;
  model: string;
  content: string;
  usage: {
    inputTokens: number;
    outputTokens: number;
    totalTokens: number;
    costUsd: number | null;
  };
  latencyMs: number;
};
