# Live Atlas HQ VPS Baseline — 2026-09-30

**Source:** read-only diagnostic executed on the current Atlas HQ VPS.

## Host
- Hostname: `atlaswallet`
- Ubuntu 24.04.4 LTS
- Kernel 6.8.0-138-generic
- KVM/OpenStack VM
- Root filesystem: 154 GB total, 50 GB used, 105 GB available (~32%)
- RAM: 7.8 GiB total, 3.4 GiB used, ~4.3 GiB available
- Swap: 4 GiB total, ~95 MiB used
- Uptime at capture: ~34 days

## Core tooling
Available: Git 2.43.0, Node.js 22.23.2, npm/npx 10.9.8, Python 3.12.3, Docker 29.7.2, Docker Compose 5.5.0, jq, curl.
Missing from PATH at capture: pip3 and uv. Legacy `docker-compose` is absent, but the Compose plugin is present.

## Docker footprint
24 containers total: 23 running, 1 stopped, 20 images.

Compose projects observed:
- atendimento-center
- atendimento-flow
- atlaswallet
- autohub360
- autohub360-backend
- levelab-lia
- mypets
- pixbrasil-core

## Confirmed operational services
Atendimento.Center: frontend, backend, Chatwoot, Chatwoot worker, Redis, Evolution API, PostgreSQL/pgvector.
Atendimento Flow: Typebot builder/viewer, PostgreSQL, Redis.
Other applications: LeveLab LIA, MyPets API, PiXBrasil API/Redis, AutoHub360 API/worker/scheduler/Redis, AtlasWallet backend/worker/Redis/Caddy.

A stopped `atendimento-recovery-postgres` container exists and requires classification before cleanup.

## Networks
Observed networks include `atendimento_internal`, `atendimento-flow_internal`, `atlaswallet_internal`, `autohub_internal`, `autohub_egress`, `levelab-lia_lia-net`, `mypets_internal`, `mypets_edge`, `pixbrasil-internal`, and shared `platform_edge`.

## Persistent volumes
Confirmed volumes exist for Atendimento PostgreSQL/Redis, Chatwoot storage, Evolution instances, Typebot PostgreSQL/Redis, AtlasWallet Redis/Caddy and PiXBrasil Redis.

No destructive cleanup is authorized until backup/recovery mapping is completed.

## Public exposure
UFW is active. Inbound is limited to SSH 22022 and HTTP/HTTPS 80/443.
Application listeners observed on 127.0.0.1 include 8080 and 8095.
Caddy publishes 80/443 and is attached to AtlasWallet, MyPets edge and platform_edge networks.

## Important findings
1. Existing human/admin account `atlas` is privileged (sudo + docker) and must not be reused for the agent runtime. Atlas.Dev uses `atlas-agent`.
2. Multiple high-memory Next.js/Node processes run outside the current Docker map and must be identified before freezes.
3. n8n was not confirmed by the first diagnostic. Absence is not yet proven.
4. Typebot, Evolution and Chatwoot are confirmed and reusable.
5. There appears to be enough resource headroom for a conservative first Atlas runtime, but not for wasteful parallelism/local GPU inference.

## Provisional classification
KEEP / CORE:
- Docker/containerd
- Caddy edge
- Atendimento.Center backend/frontend
- Chatwoot
- Evolution
- Atendimento PostgreSQL/Redis
- Typebot
- platform_edge

REVIEW BEFORE FREEZE:
- AtlasWallet application stack
- PiXBrasil
- LeveLab LIA
- MyPets
- AutoHub360
- host-level Node/Next processes
- stopped recovery PostgreSQL

UNKNOWN / DISCOVER NEXT:
- n8n location/runtime
- host-level Node/Next process ownership
- per-container resource usage
- image/volume disk footprint
- backup state
- external DNS/domain mapping

## Next action
Run the Phase 2 read-only diagnostic, then finalize the KEEP/FREEZE/REVIEW map and install Atlas.Dev-00.
