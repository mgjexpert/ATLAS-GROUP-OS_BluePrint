# Atlas HQ Consolidation Plan — 2026-09-30

## Verified Phase 2 findings

### Resource use

The largest current container memory users are:
- Chatwoot worker ~495 MiB
- Typebot builder ~474 MiB
- Typebot viewer ~423 MiB
- Chatwoot web ~371 MiB

The remaining application services are comparatively light.

Docker disk usage:
- images ~21.26 GB;
- local volumes ~206 MB;
- build cache ~16.89 GB;
- ~15.98 GB of build cache is reclaimable.

No cleanup is authorized until backup/recovery classification is complete.

### Project footprint

Observed project directories:
- Atendimento.Center: ~2.3 MB
- Atendimento Flow: ~720 MB
- AutoHub360: <1 MB
- MyPets: ~5 MB
- AtlasWallet: ~433 MB
- LeveLab LIA: ~1.7 MB
- PiXBrasil: ~12 MB

### Process attribution

The high-memory Next.js/Node/Ruby processes visible in the host process table are containerized; cgroup evidence maps them to Docker scopes. They are not evidence of unknown host-native application daemons.

### n8n

A project directory exists at:
`/srv/platform/n8n`

No active n8n process or systemd service was observed in the Phase 2 audit.

Classification: **PRESENT ON DISK / NOT CONFIRMED RUNNING**.

## Portfolio intent supplied by the PDG

### Core / keep online
- Atendimento.Center
- Chatwoot
- Evolution
- Typebot
- PostgreSQL / pgvector
- Redis
- shared edge/network components required by the above
- future Atlas HQ services

### Freeze / cold
These projects may be offline for an indefinite period after recovery packages are created:
- MyPets
- LeveLab LIA
- PiXBrasil
- AutoHub360

### AtlasWallet
The application itself currently has no required operational role and may be retired.

However, the Caddy container currently located inside the AtlasWallet stack is a shared infrastructure dependency.

Required sequence:
1. extract Caddy configuration and persistent Caddy state;
2. create a new `atlas-edge` or shared-infrastructure Compose stack;
3. attach it to the required shared networks;
4. verify every active hostname/route;
5. cut over;
6. only then stop/archive/remove the remaining AtlasWallet application containers.

## Safe consolidation sequence

### Phase A — Recovery before shutdown
For every project scheduled for cold state:
- record repository + commit;
- record Compose files;
- record domain/routes;
- identify database/volume state;
- create/verify backup where stateful;
- create recovery instructions.

### Phase B — Edge extraction
Move the reverse proxy out of AtlasWallet ownership.

Target:
```text
/srv/platform/atlas-edge
  docker-compose.yml
  Caddyfile / config
  persistent caddy data/config volumes
```

### Phase C — Freeze non-core apps
After recovery validation:
- AutoHub360
- MyPets
- LeveLab LIA
- PiXBrasil
- AtlasWallet application components

Stop first. Do not delete immediately.

Observe core stack stability before removing containers/images.

### Phase D — Reclaim safe disk
After recovery verification and a stabilization period:
- prune unused build cache;
- remove obsolete images only when confirmed unused;
- retain required named volumes/backups.

### Phase E — Atlas.Dev install
Install:
- `atlas-agent` service identity;
- uv / pinned Python runtime;
- atlashub-digital/claude-code;
- Claude Code harness;
- ECC core profile;
- AgentShield;
- OpenRouter free-first policy;
- systemd units for Atlas Agent Engine and evidence collector.

### Phase F — First autonomous mission
Atlas.Dev-00 receives sanitized evidence and produces:
- service inventory;
- dependency map;
- security observations;
- cost opportunities;
- final Atlas Reset 2026 proposal.

## Resource expectation after freeze

The current non-core stacks are not the main memory consumers. Chatwoot and Typebot dominate RAM usage.

Therefore freezing non-core projects primarily reduces:
- operational complexity;
- attack surface;
- maintenance burden;
- image/build footprint;
- background traffic/process count.

It will not transform the host into a large-memory machine.

Atlas V1 should therefore remain:
- low-concurrency;
- API-model based;
- no local large LLMs;
- no unnecessary duplicate databases/services.

## Next execution gate

Before any destructive removal:
1. build recovery packages;
2. extract shared Caddy;
3. verify core routing;
4. take backups;
5. stop non-core stacks;
6. observe;
7. only then consider deletion.
