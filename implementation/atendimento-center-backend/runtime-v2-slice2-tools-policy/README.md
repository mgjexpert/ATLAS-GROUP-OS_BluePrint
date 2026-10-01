# Atlas Intelligence Runtime V2 — Slice 2: Tools + Policy

Depends on Runtime V2 Slice 1.

Purpose:

```text
Run
 -> tool proposal
 -> ToolRegistry
 -> ActionEnvelope
 -> PolicyEngine
 -> ToolRunner
 -> RunStep / RuntimeAction / RuntimeEvent
```

This slice only executes `sideEffect=none` tools.

Any registered tool with a side effect is returned as `approval_required` and is not executed. ApprovalEngine arrives in Slice 3.

## Initial built-in tool

`atlas.runtime.inspect_run`

It reads one RuntimeRun and its steps/events inside the current tenant.

## API surface

- `GET /api/v1/runtime/tools`
- `POST /api/v1/runtime/tool-grants`
- `POST /api/v1/runtime/runs/:runId/actions`

The action endpoint exists to exercise the governed execution corridor before model tool-calling is connected. Later, AgentRuntime calls the same RuntimeActionService internally.

## Invariants

- unknown tool: deny;
- disabled tool: deny;
- missing grant: deny;
- side-effect tool: approval_required;
- read-only granted tool: allow;
- every proposal/policy/execution is durable;
- ToolRunner executes only after PolicyEngine returns allow;
- tenant boundaries are rechecked inside the tool.
