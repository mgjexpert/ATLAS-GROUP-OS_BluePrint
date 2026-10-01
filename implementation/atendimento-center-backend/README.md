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

### 2. Group OS Foundation

Path: `group-os-foundation/`

Provides:

- BusinessUnit / Branch / Team;
- Project / Goal / Task;
- Decision / Policy / Approval;
- CostCenter / Budget / UsageRecord;
- initial Atlas internal organization bootstrap.

### 3. Group OS Control Plane API

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
ToolRegistry
  -> ActionEnvelope
  -> PolicyEngine
  -> read-only ToolRunner
  -> Run/Step/Audit
  -> ApprovalEngine
```
