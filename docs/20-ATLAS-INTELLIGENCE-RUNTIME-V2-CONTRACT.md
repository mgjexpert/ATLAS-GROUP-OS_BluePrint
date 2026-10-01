# Atlas Intelligence — Runtime V2 Contract

Date: 2026-10-01
Status: **IMPLEMENTATION CONTRACT**

## Runtime boundary

Atlas Intelligence is the reusable runtime for Atlas agents.

It is independent from:

- a specific LLM provider;
- a specific product UI;
- a specific communication channel;
- ECC/Claude Code;
- one tenant or venture.

## 1. ModelGateway

### Contract

```ts
interface ModelGateway {
  generate(request: ModelRequest): Promise<ModelResponse>;
  stream(request: ModelRequest): AsyncIterable<ModelEvent>;
  supports(capability: ModelCapability): boolean;
  embed?(request: EmbeddingRequest): Promise<EmbeddingResponse>;
}
```

### Provider contract

```ts
interface ModelProvider {
  readonly id: string;
  generate(request: ProviderModelRequest): Promise<ProviderModelResponse>;
  stream?(request: ProviderModelRequest): AsyncIterable<ProviderModelEvent>;
  supports(capability: ModelCapability): boolean;
}
```

Initial provider:

- `OpenRouterProvider`.

Later providers:

- OpenAI;
- Anthropic;
- Google;
- local/Ollama/vLLM.

### Model request

Minimum fields:

- logical model/policy;
- messages/context;
- temperature/max output;
- structured-output schema;
- available tool schemas;
- tenant/organization;
- agent/run;
- budget/cost policy;
- trace context.

Provider credentials are resolved from secret references outside agent prompts.

## 2. AgentRuntime

### Responsibility

`AgentRuntime` orchestrates one bounded run.

It owns:

- context assembly;
- agent version resolution;
- policy checks;
- model calls;
- tool proposal loop;
- approval suspension/resume;
- verification;
- output finalization;
- memory candidates;
- trace completion.

It does not contain product-specific business logic.

### Minimal contract

```ts
interface AgentRuntime {
  start(input: StartRunInput): Promise<RunHandle>;
  resume(input: ResumeRunInput): Promise<RunHandle>;
  cancel(runId: string, actor: ActorContext): Promise<void>;
}
```

## 3. ActionEnvelope

No model-produced tool action executes directly.

```ts
type ActionEnvelope = {
  id: string;
  runId: string;
  stepId: string;
  tool: string;
  toolVersion?: string;
  capability: string;
  input: unknown;

  sideEffect: 'none' | 'reversible' | 'material' | 'destructive';
  risk: 'low' | 'medium' | 'high' | 'critical';

  requestedBy: {
    agentId: string;
    agentVersionId?: string;
  };

  target?: {
    organizationId?: string;
    tenantId?: string;
    projectId?: string;
    resource?: string;
  };

  approval: {
    required: boolean;
    policyIds: string[];
    approvalRequestId?: string;
  };

  idempotencyKey?: string;
  timeoutMs?: number;
};
```

The envelope is created by trusted runtime code from a validated model tool proposal.

## 4. ToolRegistry

```ts
type ToolDefinition = {
  code: string;
  version: string;
  description: string;

  capability: string;
  inputSchema: object;
  outputSchema?: object;

  sideEffect: 'none' | 'reversible' | 'material' | 'destructive';
  defaultRisk: 'low' | 'medium' | 'high' | 'critical';

  approvalPolicy?: string;
  secretRefs?: string[];

  timeoutMs: number;
  retryPolicy?: {
    maxAttempts: number;
    backoffMs: number;
  };
};
```

Tool registration is separate from per-agent permission.

A registered tool is not automatically available to every agent.

## 5. PolicyEngine

### Input

- actor;
- organization/tenant;
- agent + version;
- action envelope;
- tool definition;
- current grants;
- budget state;
- environment;
- relevant constitutional policy.

### Decision

```ts
type PolicyDecision =
  | { result: 'allow'; policyIds: string[] }
  | { result: 'approval_required'; policyIds: string[]; reason: string }
  | { result: 'deny'; policyIds: string[]; reason: string };
```

Policy evaluation happens before any side effect.

## 6. ApprovalEngine

Approval is durable state, not a chat convention.

Approval request minimum:

- action envelope;
- requesting agent;
- reason;
- risk;
- expected effect;
- reversibility;
- expiry;
- required approver class;
- decision;
- deciding actor;
- timestamp.

A suspended run may resume only after the approval decision is persisted and revalidated against current policy.

## 7. Run / Step / Trace

### Run

Minimum:

- id;
- organization/tenant;
- agent + version;
- trigger/source;
- goal/task reference;
- status;
- started/finished timestamps;
- final result;
- model usage;
- cost;
- error;
- trace ID.

### Step

Minimum:

- run ID;
- ordinal;
- kind;
- status;
- model/tool reference;
- input summary;
- output summary;
- latency;
- token/cost data;
- approval reference;
- artifact references.

Suggested step kinds:

- context;
- model;
- tool_proposal;
- policy;
- approval;
- tool_execution;
- verifier;
- response;
- memory.

### Trace

Trace correlates one user/business operation across:

- API;
- agent runtime;
- model calls;
- queue jobs;
- tools;
- webhooks;
- audit.

## 8. Runtime events

Canonical events:

- `run.started`
- `run.suspended`
- `run.resumed`
- `run.completed`
- `run.failed`
- `step.started`
- `step.completed`
- `response.delta`
- `tool.proposed`
- `tool.started`
- `tool.completed`
- `tool.failed`
- `approval.required`
- `approval.decided`
- `handoff.required`
- `memory.candidate`
- `memory.persisted`
- `error`

The same event model should support SSE/WebSocket/UI and durable audit.

## 9. Memory contract

Runtime memory scopes:

### Working Context

Ephemeral to one run.

### Relationship Memory

Person/agent relationship facts and conversation continuity.

### Operational Memory

Projects/tasks/decisions/status.

### Organization Knowledge

Durable organization/client/process knowledge.

### Agent-Pack Knowledge

Approved instructions/domain material bound to a versioned agent pack.

Memory extraction follows:

```text
candidate
 -> validation
 -> policy
 -> scope resolution
 -> persistence
```

No LLM writes directly to durable memory.

## 10. Execution queues

Phase after core runtime contracts:

- `atlas.agent`
- `atlas.tools`
- `atlas.followups`
- `atlas.knowledge`
- `atlas.notifications`
- `atlas.integrations`
- `atlas.portfolio`
- `atlas.automation`
- `atlas.signals`
- `atlas.smm`

Queue payloads contain IDs/references, not large prompt/context blobs.

Workers reload canonical state from the database.

## 11. First vertical slice

The first Runtime V2 vertical slice is intentionally small:

```text
API request
 -> resolve tenant + agent
 -> create Run
 -> ModelGateway/OpenRouterProvider
 -> no-side-effect response
 -> Step/Trace
 -> final response
```

Second slice:

```text
model proposes read-only tool
 -> ToolRegistry
 -> PolicyEngine
 -> ActionEnvelope
 -> ToolRunner
 -> verifier
 -> response
```

Third slice:

```text
model proposes approval-required side effect
 -> ActionEnvelope
 -> PolicyEngine
 -> ApprovalRequest
 -> suspend Run
 -> human approval
 -> resume Run
 -> execute
 -> audit
```

## 12. Acceptance criteria for Runtime V2 foundation

The foundation is complete when:

- agents no longer call `OpenRouterService` directly;
- provider routing is behind `ModelGateway`;
- every run receives a durable Run ID;
- model/tool steps are traceable;
- tools are registered with typed schemas and risk metadata;
- side-effect tools cannot bypass policy;
- approval-required actions suspend rather than execute;
- audit can reconstruct who/what/why/outcome;
- existing Relationship Engine can call Runtime V2 without losing current behavior.
