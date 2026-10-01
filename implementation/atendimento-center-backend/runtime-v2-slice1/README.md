# Atendimento.Center Backend — Runtime V2 Slice 1 Overlay

Status: implementation-ready overlay

Target upstream:
`nexflowx-hub/atendimento.center-backend`

Pinned upstream commit used for this overlay:
`f47dc6a31db118e0047decd1ea50e6a97a30df48`

Purpose:
implement the first Atlas Intelligence Runtime V2 vertical slice without changing the existing Relationship Engine contract.

## Slice 1

```text
POST /api/v1/runtime/runs
  -> authenticated tenant
  -> resolve Agent + latest AgentVersion
  -> create ai.runtime_runs
  -> create context step
  -> AgentRuntime
  -> ModelGateway
  -> OpenRouterProvider
  -> model step + audit.runtime_events
  -> finalize run
  -> response + runId + traceId
```

No tools, approvals, queues or side-effect execution are introduced in this slice.

## Overlay contents

- `database/migrations/20261001_atlas_runtime_v2_slice1.sql`
- `prisma/runtime-v2-models.prisma`
- `src/runtime/**`
- `patches/app.module.patch`

## Integration order

1. Apply the SQL migration to Atlas Platform Core using the same controlled migration process used by existing Atlas migrations.
2. Append the Prisma models to `prisma/schema.prisma`.
3. Copy `src/runtime/` into the backend.
4. Apply `patches/app.module.patch`.
5. Run `npm run prisma:generate`.
6. Run `npm run build`.
7. Deploy to staging/test before production.
8. Execute the smoke request documented below.

## Runtime API

The slice exposes both creation and trace inspection:

- `POST /api/v1/runtime/runs`
- `GET /api/v1/runtime/runs/:id`

Request:

```http
POST /api/v1/runtime/runs
Authorization: Bearer <supabase-access-token>
x-tenant-slug: atendimento-center
Content-Type: application/json
```

Body:

```json
{
  "agentCode": "atlas-dev-00",
  "input": "Summarize the current task in one paragraph.",
  "metadata": {
    "source": "runtime-v2-smoke"
  }
}
```

Response shape:

```json
{
  "runId": "uuid",
  "traceId": "uuid",
  "status": "completed",
  "provider": "openrouter",
  "model": "provider/model",
  "content": "...",
  "usage": {
    "inputTokens": 0,
    "outputTokens": 0,
    "totalTokens": 0,
    "costUsd": null
  },
  "latencyMs": 0
}
```

## Guardrails

- Uses existing SupabaseAuthGuard + TenantGuard + TenantRoleGuard.
- Requires an enabled agent belonging to the authenticated tenant.
- Does not expose agent system prompts in the HTTP response.
- Does not execute tools.
- Does not permit side effects.
- Stores durable run/step/event records.
- Does not modify the existing `ai.agent_runs` Relationship Engine table.
- Provider-specific HTTP behavior is isolated behind `ModelProvider`.
- Runtime code does not call the legacy `OpenRouterService`.

## Next slice

After this vertical slice is live and traced end-to-end:

`ToolRegistry -> ActionEnvelope -> PolicyEngine -> read-only ToolRunner`.
