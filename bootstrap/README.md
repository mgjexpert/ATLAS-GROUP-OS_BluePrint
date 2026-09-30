# Atlas.Dev-00 Bootstrap

This directory contains the first safe deployment scaffold for the Atlas HQ VPS.

## V0 security model

Atlas.Dev-00 does **not** receive direct Docker socket access and does not receive root.

A root-owned collector creates a sanitized infrastructure snapshot. The agent receives only the resulting evidence files.

Flow:

```text
Host / Docker / systemd
        |
root-owned snapshot collector
        |
sanitized evidence
        |
/var/lib/atlas/inventory/current
        |
Atlas.Dev-00 (user: atlas)
        |
FCC Agent Engine + Claude Code + ECC
        |
OpenRouter free-first model route
        |
local analysis/report files
```

## Required host prerequisites

- Debian/Ubuntu-family Linux for the current bootstrap script
- systemd
- Docker already installed if Docker inventory is desired
- Git
- curl
- jq
- Node.js >= 18
- outbound HTTPS access
- OpenRouter API key

The bootstrap script installs normal OS utilities but intentionally refuses to install/replace Node.js automatically. This avoids modifying an existing production runtime blindly.

## Files

- `preflight.sh` — checks the VPS before changes
- `install-atlas-dev.sh` — installs the V0 runtime and service user
- `atlas-dev.env.example` — non-secret environment template
- `scripts/atlas-host-snapshot.sh` — sanitized evidence collector
- `scripts/run-first-mission.sh` — launches the first non-interactive mission
- `prompts/atlas-dev-first-mission.md` — first mission
- `systemd/atlas-agent-engine.service` — local-only FCC service
- `systemd/atlas-host-snapshot.service` — collector unit
- `systemd/atlas-host-snapshot.timer` — hourly evidence refresh
- `systemd/atlas-dev-first-mission.service` — one-shot first mission

## Installation sequence

1. Run `preflight.sh`.
2. Place the real secret values in `/etc/atlas/atlas-agent-engine.env`.
3. Run `install-atlas-dev.sh`.
4. Start `atlas-agent-engine.service`.
5. Run one sanitized snapshot.
6. Run AgentShield.
7. Start `atlas-dev-first-mission.service`.
8. Review reports before granting any additional permission.

## Important

Do not expose FCC port 8082 publicly. The provided environment binds it to `127.0.0.1`.

Do not put API keys in this repository.
