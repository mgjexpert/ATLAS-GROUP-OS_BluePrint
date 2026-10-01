# Atendimento.Center → Atlas Platform Implementation

This directory contains the implementation overlays that evolve the current Atendimento.Center backend into the first Atlas Platform / Group OS control plane.

Target upstream baseline:

`nexflowx-hub/atendimento.center-backend@f47dc6a31db118e0047decd1ea50e6a97a30df48`

## Implemented overlays

### 1. Runtime V2 Slice 1

Path: `runtime-v2-slice1/`

Provides:

- generic RuntimeRun / RuntimeStep / RuntimeEvent;
- ModelGateway;
- OpenRouterProvider;
- authenticated runtime start endpoint;
- trace inspection endpoint;
- durable model usage/latency/cost fields;
- no tools or side effects.

### 2. Runtime V2 Slice 2 — Tools + Policy

Path: `runtime-v2-slice2-tools-policy/`

Provides:

- ToolRegistry;
- per-agent ToolGrant lifecycle;
- ActionEnvelope;
- PolicyEngine;
- read-only ToolRunner;
- durable RuntimeAction lifecycle;
- built-in `atlas.runtime.inspect_run`;
- grant and execution audit.

Side-effect tools are suspended as `approval_required` and are never executed in this slice.

### 3. Runtime V2 Slice 3 — ApprovalEngine

Path: `runtime-v2-slice3-approval-engine/`

Provides:

- durable approval requests and decisions;
- owner/admin decision endpoint;
- suspended RuntimeAction lifecycle;
- policy re-check after approval;
- approval-step completion and audit;
- reversible proof tool `atlas.portfolio.update_task_status`.

Human approval never bypasses ToolGrant or current policy.

### 4. Runtime V2 Slice 4 — Model Tool-Calling

Path: `runtime-v2-slice4-model-tools/`

Provides:

- provider-native tool-call parsing behind ModelGateway;
- only actively granted tools exposed to the model;
- canonical Atlas tool names separated from provider wire aliases;
- bounded model/tool loop;
- read-only tool result continuation;
- suspended run state for approval-required actions;
- automatic model continuation after approved action execution;
- automatic run cancellation after denied approval;
- cumulative run usage/cost state.

The model still never calls ToolRunner directly.

### 5. Runtime V2 Slice 5 — Execution Layer

Path: `runtime-v2-slice5-execution-layer/`

Provides:

- canonical Atlas queue names;
- BullMQ `atlas.agent` producer;
- durable `ExecutionJob` records;
- queue payloads containing IDs only;
- dedicated `atlas_agent_worker`;
- bounded worker concurrency;
- separate Atlas Redis logical DB;
- async runtime enqueue/status API;
- synchronous Runtime V2 path retained as fallback.

Queue delivery completion and RuntimeRun outcome are recorded separately: a queue job can complete successfully while the resulting RuntimeRun is suspended awaiting approval.

### 6. Runtime V2 Slice 6 — Knowledge + Operational Memory

Path: `runtime-v2-slice6-knowledge-memory/`

Provides:

- canonical `knowledge.sources/documents/chunks`;
- deterministic SHA-256 document deduplication;
- trusted text normalization/chunking;
- PostgreSQL full-text retrieval;
- organization/project-scoped search;
- curated `portfolio.project_memories`;
- Knowledge ingestion/search API;
- read-only `atlas.knowledge.search` runtime tool.

Relationship Memory remains unchanged and separate.

### 7. Group OS Foundation

Path: `group-os-foundation/`

Provides:

- BusinessUnit / Branch / Team;
- Project / Goal / Task;
- Decision / Policy / Approval;
- CostCenter / Budget / UsageRecord;
- initial Atlas internal organization bootstrap.

### 8. Group OS Control Plane API

Path: `group-os-control-plane/`

Provides:

- organization structure view;
- project list/tree;
- project creation;
- goal creation;
- task creation/status transitions;
- durable decision proposals;
- pending approval queue view.

Approval execution is intentionally deferred to ApprovalEngine.

## One-shot staging

From the Blueprint checkout:

```bash
./implementation/atendimento-center-backend/apply-atlas-v2-foundation.sh \
  /path/to/atendimento.center-backend
```

The script refuses a dirty or unexpected upstream checkout.

It stages code/migrations and runs Prisma/build verification when dependencies exist.

It does **not**:

- apply database migrations;
- execute the organization seed;
- deploy;
- restart production;
- grant agent permissions.

## Next implementation block

```text
Agent Packs
  -> versioned role/capability/knowledge bundles
  -> model policy
  -> tool grants
  -> evaluation state

Atlas Executive
  -> portfolio brief
  -> decision queue
  -> approval queue
  -> delegation to Atlas departments

Parallel hardening:
  -> preallocated RuntimeRun
  -> idempotent queue retries
  -> budget/concurrency controls
```
