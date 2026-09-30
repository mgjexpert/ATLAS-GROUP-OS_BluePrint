# 08 — First Agent Bootstrap: Atlas.Dev-00

## Objective

Install the first Atlas operational agent on the Atlas HQ VPS.

Agent:
**Atlas.Dev-00 — Founding Engineer**

The first mission is deliberately safe and observable.

## V0 mission

> Inventory the Atlas VPS and connected technical ecosystem. Do not modify production. Produce a verified infrastructure map, service/dependency inventory, risk list and Atlas Reset 2026 implementation plan.

## Why Atlas.Dev first

A technical founding agent can establish reliable ground truth before Atlas.DG is asked to manage the Group.

ATLAS.DG should be introduced after project, portfolio, agent and infrastructure state are reliable enough to manage.

## Runtime composition

```text
Atlas.Dev-00
  -> Atlas Engineering Constitution
  -> ECC engineering profile
  -> approved Atlas skills
  -> Agent Engine
       -> Claude Code first harness
       -> atlashub-digital/claude-code
  -> OpenRouter free-first model policy
  -> sanitized inventory evidence
```

## Security change from early draft

Atlas.Dev-00 V0 does **not** get direct Docker socket access.

Docker socket membership is effectively a privileged capability and raw `docker inspect`/logs can expose secret values.

Instead:

```text
host + Docker
  -> root-owned fixed collector
  -> sanitized snapshot
  -> /var/lib/atlas/inventory/current
  -> Atlas.Dev-00 read access
```

The agent itself runs as the non-root Linux user `atlas`.

## Phase 0 — prerequisites

- non-root Linux service account;
- dedicated directories;
- secret environment file outside Git;
- local-only FCC listener;
- sanitized inventory collector;
- persistent mission log;
- emergency disable through systemd;
- OpenRouter key;
- Node.js >=18 for ECC;
- outbound HTTPS.

## Phase 1 — Agent Engine

Use:
`atlashub-digital/claude-code`

V0 server configuration:
- `HOST=127.0.0.1`
- `PORT=8082`
- proxy authentication enabled;
- messaging disabled;
- voice disabled;
- raw payload logging disabled.

Keep the fork close to upstream and keep proprietary Group OS logic outside it.

## Phase 2 — engineering layer

Pilot ECC 2.2.x using the core profile for the Claude harness.

Use AgentShield before increasing permissions.

## Phase 3 — initial tools

Allowed inside the agent mission:
- Read
- Glob
- Grep
- Write inside mission workspace

Explicitly disallowed:
- Bash
- Edit
- WebFetch
- WebSearch

The deterministic bootstrap scripts may clone the public blueprint and copy sanitized evidence before the agent starts. That is outside model control.

## Phase 4 — first mission outputs

Atlas.Dev-00 creates under its mission output directory:

1. `vps-services.json`
2. `docker-compose-map.md`
3. `networks-storage.md`
4. `repos-and-deployments.md`
5. `databases.md`
6. `domains-endpoints.md`
7. `dependencies.mmd`
8. `security-observations.md`
9. `cost-opportunities.md`
10. `ATLAS-RESET-2026.md`

## Acceptance criteria

- every conclusion is evidence-linked;
- unknowns remain explicit;
- no secret values in outputs;
- no production state change;
- no agent shell execution;
- no Docker socket;
- AgentShield review completed;
- PDG can review the Reset plan before any write phase.

## Implementation files

See `bootstrap/`.

## Phase 5 — controlled promotion

Only after V0 review consider:
- GitHub write on selected repos;
- feature branches and PRs;
- backup automation;
- staging provisioning;
- controlled service actions;
- later production changes through approval gates.

## Deployment access

GitHub can prepare and version the bootstrap. Executing it on the Atlas HQ VPS requires an authorized terminal/SSH path.
