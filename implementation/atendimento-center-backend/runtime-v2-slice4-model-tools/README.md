# Atlas Intelligence Runtime V2 — Slice 4: Model Tool-Calling

Depends on Runtime V2 Slices 1-3.

This slice connects model tool proposals to the already-governed ActionEnvelope corridor.

```text
ModelGateway
  -> tool_call
  -> trusted parser
  -> RuntimeActionService
  -> PolicyEngine
  -> allow / approval_required / deny
  -> ToolRunner
  -> tool result
  -> model continues
```

## Key rules

- The model sees only registered, enabled tools for which its agent has an active ToolGrant.
- Provider-specific tool names are wire-safe aliases; canonical Atlas tool codes remain internal.
- Parallel tool calls are disabled and Slice 4 accepts at most one tool call per model turn.
- Maximum model turns per run are bounded.
- Side-effect proposals suspend the Run with durable state.
- Approval executes the action through the existing Policy/Approval corridor.
- A suspended model run resumes from persisted state after an approved action completes.
- Denied approval cancels a suspended model run.
- No model can call ToolRunner directly.

## Persistence delta

`ai.runtime_runs.state jsonb` stores trusted runtime continuation state:
- messages;
- current model turn;
- cumulative usage;
- one pending tool call.

This state is runtime-owned. It is not free-form durable memory.
