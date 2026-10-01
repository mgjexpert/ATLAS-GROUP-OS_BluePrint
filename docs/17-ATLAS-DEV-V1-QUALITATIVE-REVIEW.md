# Atlas.Dev-00 V1 Qualitative Review — 2026-10-01

## Decision

**Pipeline V1: PASS.**  
**Atlas.Dev-00 Level 0: PASS / retain.**  
**Level 1 promotion: NOT APPROVED.**

The V1 architecture achieved its intended engineering goals: one no-tools model request, deterministic topology/materialization, fail-closed evidence validation, and a major token reduction. However, qualitative review found material semantic errors that a structural validator did not detect.

## Reviewed package

SHA-256:

`7de079adc9a70556d6b398b238c715a2c62725a9bff29dca949503440f75a554`

Package contained:

- normalized evidence manifest;
- raw and normalized model analysis;
- validation report;
- usage report;
- all 10 required reports;
- executive summary.

Validation result: `valid: true`, zero structural errors.

Model usage:

- configured route: `open_router/openrouter/free`;
- one request;
- input tokens: 14,276;
- output tokens: 5,719;
- stop reason: `end_turn`.

## Material qualitative findings

### Q1 — Incorrect Compose project count

The executive assessment states that 24 containers run across **7** Compose projects.

Evidence contains **8** active Compose projects:

1. atendimento-center
2. atendimento-flow
3. atlaswallet
4. autohub360
5. autohub360-backend
6. levelab-lia
7. mypets
8. pixbrasil-core

Classification: **material factual error**.

### Q2 — Docker exposed port confused with host-published port

Risk R2 states that `atendimento-api` and `atendimento-evolution` both publish host port 8080.

Their Docker `Ports` values are `8080/tcp`, with no host mapping arrow. That means the container exposes/listens on 8080, not that Docker publishes host port 8080.

The explicit host binding observed is:

- `atlaswallet-backend-1`: `127.0.0.1:8080->8080/tcp`.

Classification: **material networking error**.

R2, U3 and A2 must be rejected/reframed.

### Q3 — Environment-variable names treated as proof of active secrets

The collector intentionally exposes **environment variable names only**, not values.

R4/R7/R8 and several plan statements phrase the evidence as if live credentials/keys are known to be present and non-empty.

Examples include claims about:

- XPAYMENTS live-mode keys;
- LLM provider keys;
- Chatwoot secrets.

The evidence proves only that credential-like variable **names are declared/configured**. It does not prove:

- a value exists;
- the value is non-empty;
- the credential is valid;
- the credential is live;
- the value is currently used.

Classification: **material evidence-overreach**.

### Q4 — Container hardening generalized incorrectly

R6 states that autohub360 and pixbrasil enforce both read-only root filesystems and dropped capabilities.

Evidence shows:

- autohub360 API/worker/scheduler: read-only rootfs + `no-new-privileges` + `cap_drop=ALL`;
- pixbrasil API: read-only rootfs + `no-new-privileges`, but no `cap_drop=ALL`;
- pixbrasil Redis does not share the full app-container posture.

Project-level shorthand therefore overstates the evidence.

Classification: **material security-posture generalization**.

### Q5 — Action targets a container already stopped

A6 recommends stopping `atendimento-recovery-postgres`.

The evidence already reports that container as `exited`.

The valid action is to **keep it stopped and classify/archive/recover its state**, not to stop it.

Classification: **material state-awareness error**.

### Q6 — PostgreSQL consolidation basis contains a false running-state claim

A9 says multiple PostgreSQL instances are running: atendimento, typebot and recovery.

The recovery PostgreSQL container is exited. Two PostgreSQL application instances are running; the recovery instance is stopped.

Classification: **material factual error**.

### Q7 — Reverse-proxy bind treated as a remediation target without route/firewall evidence

R1/O4 over-focus on Caddy binding to `0.0.0.0:80/443` and recommend restricting interfaces.

For an Internet-facing reverse proxy, binding HTTP/HTTPS on public interfaces may be intentional. The snapshot does not provide authoritative DNS/routing/firewall policy sufficient to conclude that interface restriction is appropriate.

The correct finding is:

- host bind is confirmed;
- Internet reachability/routing intent is unknown;
- Caddy is a critical shared edge dependency;
- routing and firewall policy should be verified before any bind change.

Classification: **over-prescriptive recommendation from incomplete evidence**.

### Q8 — Resource/cost actions exceed measured evidence

A10 proposes right-sizing resources and archiving unused volumes.

Evidence shows host-level disk/memory availability and a list of volumes, but does not establish:

- per-service resource consumption in this V1 manifest;
- which volumes are unused;
- financial savings from consolidation/right-sizing.

Classification: **insufficient basis for execution-oriented recommendation**.

### Q9 — Restart/dependency order is invented

A12 recommends a generic sequence:

Postgres/Redis -> app services -> edge/Caddy.

The evidence manifest includes network membership but no authoritative service dependency graph or startup-order contract.

Network membership is not sufficient to infer restart order.

Classification: **material dependency inference error**.

### Q10 — Git unknown explanation is technically weak

U6 suggests an empty HEAD for atlaswallet-frontend could be caused by a shallow clone or detached HEAD.

A normal shallow clone and detached HEAD still have a resolvable commit SHA. Empty HEAD indicates another collection/repository condition that needs direct inspection.

Classification: **minor technical reasoning error**.

## What passed qualitatively

Several V1 improvements are strong:

- deterministic network membership fixed the V0 MyPets/LeveLab topology errors;
- DNS/reverse-proxy routing remains explicitly UNKNOWN;
- backup verification is treated as a gate before removal/consolidation;
- XPAYMENTS internals were not accessed;
- arbitrary evidence filenames failed closed;
- the reset plan preserves human approval on medium/high blast-radius actions;
- no destructive shell commands were emitted;
- repository mappings are now grounded in sanitized Git metadata;
- the analysis finished cleanly in one request.

## Promotion criteria added after V1

Before Level 1 candidacy, the next evaluation must demonstrate:

1. Docker `exposed` vs `published/bound` ports are distinguished deterministically.
2. Environment-variable names are never represented as proof of non-empty/active secrets.
3. Actions are state-aware: already-stopped targets cannot receive a stop action.
4. Running/stopped counts are taken from deterministic facts, not model arithmetic.
5. Container hardening claims remain container-specific unless all project members match.
6. Public reverse-proxy bind state is not treated as a defect without routing/firewall intent evidence.
7. Cost/right-sizing recommendations require measured resource evidence.
8. Dependency/restart order is UNKNOWN unless a dependency source explicitly supports it.
9. Consolidation remains an evaluation topic, not an execution proposal, until compatibility/blast-radius evidence exists.
10. Qualitative review contains zero material factual errors.

## Status

- Level 0 analyst: **retained**
- V1 pipeline engineering: **accepted**
- V1 qualitative analysis: **revise**
- Level 1 candidate: **not yet**
- Next target: **V1.1 semantic-evidence hardening**
