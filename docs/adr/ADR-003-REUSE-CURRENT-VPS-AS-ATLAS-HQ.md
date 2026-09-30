# ADR-003 — Reuse Current VPS as Atlas HQ V1

**Status:** Accepted  
**Date:** 2026-09-30

## Context

A live read-only audit of the current VPS showed:

- Ubuntu 24.04.4 LTS;
- Docker 29.7.2 / Compose 5.5.0;
- Node.js 22.23.2;
- ~154 GB disk with ~105 GB available;
- ~7.8 GiB RAM with ~4.3 GiB available at capture;
- UFW enabled;
- SSH on 22022;
- shared edge via Caddy;
- existing Atendimento.Center / Chatwoot / Evolution / Typebot / PostgreSQL / Redis;
- additional non-production project stacks that can be paused;
- n8n project directory exists at `/srv/platform/n8n`, but no active n8n process/service was confirmed;
- almost 16 GB of reclaimable Docker build cache;
- persistent project data stored in named volumes.

## Decision

Use the current VPS as **Atlas HQ V1** rather than provisioning a new clean VPS.

The Atlas runtime must remain isolated by:
- dedicated service identity `atlas-agent`;
- no sudo group;
- no Docker group;
- no direct Docker socket;
- local-only agent engine listener;
- explicit tool/approval policies;
- sanitized infrastructure evidence for the first agent mission.

## Rationale

The existing VPS already contains most of the shared operational stack Atlas needs:
- communications;
- workflows;
- data;
- channels;
- reverse proxy;
- container runtime;
- networking.

Provisioning another VPS would duplicate infrastructure, increase operating cost and create another environment to maintain before Atlas has generated operational value.

The current non-production application portfolio can be frozen to recover memory, storage and operational focus.

## Important dependency

The current Caddy container belongs to the AtlasWallet Compose project but already serves as a shared edge gateway.

AtlasWallet must therefore **not** be removed before the edge gateway is extracted into an Atlas/shared-infrastructure stack.

## When to introduce a separate VPS later

A new dedicated VPS becomes justified when one or more of these conditions are met:
- Atlas HQ requires stronger blast-radius isolation from customer-facing workloads;
- a client requires dedicated infrastructure;
- resource pressure makes the shared host unsafe;
- Atlas Agent workers need materially different scaling/security profiles;
- local model/GPU infrastructure is introduced;
- production SLA requirements justify independent failure domains.

## Consequence

Atlas HQ V1 is an **in-place controlled consolidation**, not a greenfield rebuild.
