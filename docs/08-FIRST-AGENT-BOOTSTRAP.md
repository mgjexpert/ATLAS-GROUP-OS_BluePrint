# 08 — First Agent Bootstrap: Atlas.Dev-00

## Objective

Install the first Atlas operational agent on the Atlas HQ VPS.

Agent:
**Atlas.Dev-00 — Founding Engineer**

The first mission is deliberately safe and observable.

## V0 mission

> Inventory the Atlas VPS and connected technical ecosystem. Do not modify production. Produce a verified infrastructure map, service/dependency inventory, risk list and Atlas Reset 2026 implementation plan.

## Why Atlas.Dev first

A technical founding agent can:
- understand the existing VPS;
- document current reality;
- identify duplicate services;
- map Docker/network/storage;
- inspect repositories;
- prepare safe migration/freeze plans;
- build subsequent Atlas infrastructure.

ATLAS.DG should be introduced after the Group OS has reliable project/portfolio/agent state to manage.

## Runtime composition

```text
Atlas.Dev-00
  -> Atlas Engineering Constitution
  -> ECC engineering profile
  -> approved Atlas skills
  -> Agent Engine
       -> Claude Code / Codex / OpenCode/etc.
       -> atlashub-digital/claude-code
  -> OpenRouter free-first model policy
  -> scoped tools
```

## Phase 0 — prerequisites

Do not deploy until these are ready:
- non-root Linux service account for Atlas Agent Engine;
- dedicated working directories;
- secret mechanism;
- Docker read-only inspection path or scoped socket proxy where possible;
- GitHub credential with minimal required repo scope;
- OpenRouter key;
- persistent logs;
- audit storage;
- outbound network policy;
- emergency disable mechanism.

## Phase 1 — install Agent Engine

Candidate:
`atlashub-digital/claude-code`

Keep the fork close to upstream.

Do not put Group OS proprietary logic inside it.

## Phase 2 — install engineering layer

Pilot ECC with a conservative/core profile.

Enable only the agents/skills necessary for:
- repository inspection;
- architecture analysis;
- planning;
- security review;
- testing;
- documentation.

Run AgentShield against the final agent/MCP/hook configuration before enabling write capabilities.

## Phase 3 — Atlas.Dev agent pack

Use `config/agent-packs/atlas-dev.yaml`.

Initial permission level:
**observe/recommend**.

Allowed:
- read system information;
- read Docker metadata;
- read repository metadata;
- read logs within approved scopes;
- inspect service health;
- create analysis artifacts in its workspace;
- create/update documentation in approved GitHub repos if explicitly enabled.

Not initially allowed:
- stop/start production containers;
- change firewall;
- alter DNS;
- delete volumes;
- write production DB;
- rotate credentials;
- merge/deploy production;
- access XPAYMENTS internals.

## Phase 4 — first mission outputs

Atlas.Dev-00 must produce:

1. `inventory/vps-services.json`
2. `inventory/docker-compose-map.md`
3. `inventory/networks-storage.md`
4. `inventory/repos-and-deployments.md`
5. `inventory/databases.md`
6. `inventory/domains-endpoints.md`
7. `inventory/dependencies.mmd`
8. `reports/security-observations.md`
9. `reports/cost-opportunities.md`
10. `plans/ATLAS-RESET-2026.md`

No production change is needed to complete this milestone.

## Acceptance criteria

- inventory is reproducible;
- each finding links to evidence;
- unknowns are explicitly listed;
- no secret values appear in artifacts/logs;
- no production service changed state;
- no destructive command executed;
- AgentShield/security checks pass at agreed threshold;
- PDG can review the Reset plan before any write phase.

## Phase 5 — controlled write privilege

Only after V0 review:
- feature branches;
- documentation commits;
- backup scripts;
- staging provisioning;
- controlled container migrations;
- later production changes via approvals.

## VPS access note

This blueprint repository defines the implementation, but deployment requires an authorized VPS access mechanism (SSH/terminal/agent bootstrap). GitHub access alone cannot execute commands on the VPS.
