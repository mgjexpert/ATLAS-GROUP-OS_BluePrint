# ADR-004 — Atendimento.Center as Atlas Platform Control Plane

Date: 2026-10-01
Status: Accepted

## Context

Atlas already has a production-oriented NestJS/PostgreSQL backend in `nexflowx-hub/atendimento.center-backend` with organization/tenant primitives, agent registry/versioning, channel bindings, conversation state, relationship memory, integrations, runs, follow-ups and audit records.

Creating a separate Atlas backend would duplicate identity, tenancy, channels, integrations and agent state.

At the same time, Atlas must not become structurally coupled to customer-support semantics.

## Decision

Evolve Atendimento.Center into the first **Atlas Platform / Group OS control plane**.

Create a reusable **Atlas Intelligence Runtime V2** within/alongside that codebase using clean module boundaries.

Product-specific behavior remains outside the generic runtime.

The repository name may remain unchanged during V2 implementation; repository/product renaming is not required to start.

## Consequences

Positive:

- reuse deployed infrastructure and schema;
- preserve working channel/relationship capabilities;
- reduce migration risk;
- make agent/runtime improvements immediately useful to existing ventures;
- avoid a second source of truth.

Required discipline:

- generic Runtime V2 modules cannot depend on FaceLove/MyTrainX/SMM-specific semantics;
- provider integrations move behind ModelGateway;
- side effects move behind ToolRegistry/Policy/Approval;
- organizational entities are added as first-class Group OS concepts;
- relationship memory remains a specialized module;
- Atlas constitutional policy remains above ordinary agents.

## Rejected alternative

Create a new standalone Atlas backend and later migrate Atendimento.Center into it.

Rejected because it duplicates core capabilities before Atlas has a validated need for a separate physical service boundary.
