# Atlas.Dev Validated Evaluation Pipeline V1

## Purpose

The first Atlas.Dev-00 mission proved that the agent can inventory and reason about Atlas HQ, but also exposed three design weaknesses: cross-file topology errors, unsafe operational wording, and excessive repeated-context token use.

V1 changes the architecture without granting more authority.

## Principle

**Deterministic facts first. Model judgment second. Deterministic validation last.**

Flow:

1. the root-owned snapshot collector creates sanitized evidence;
2. trusted code compacts that evidence into one normalized manifest;
3. one no-tools model request returns structured analysis JSON;
4. trusted code validates schema, evidence references, reset phases and approval metadata;
5. trusted code materializes all reports;
6. topology is generated directly from observed Docker network membership.

## Security delta from V0

The evaluation model no longer receives Claude Code filesystem tools. It has no Bash, Read/Glob/Grep, Write/Edit, MCP, web tools or Docker socket access.

The evaluation systemd unit is restricted to loopback networking. The model-side process talks to the existing local FCC service, while FCC remains the external provider gateway and retains the configured routing policy.

The model returns one JSON analysis. Trusted code owns filesystem writes.

## Deterministic outputs

These reports are generated from evidence rather than free-form topology synthesis:

- `vps-services.json`
- `docker-compose-map.md`
- `networks-storage.md`
- `repos-and-deployments.md`
- `databases.md`
- `domains-endpoints.md`
- `dependencies.mmd`

The model contributes judgment to:

- `security-observations.md`
- `cost-opportunities.md`
- `ATLAS-RESET-2026.md`
- `executive-summary.md`

## V1 validation gates

The structural validator fails closed when it detects:

- an unexpected analysis schema;
- evidence references that do not exist in the snapshot;
- confirmed risks/opportunities without evidence references;
- invalid confidence or severity values;
- duplicate analysis/action IDs;
- missing or out-of-order Atlas Reset phases;
- medium/high blast-radius actions marked as requiring no approval;
- backup-required actions marked as requiring no approval;
- executive-summary IDs that do not resolve to validated risks/actions.

No reports are materialized when structural validation fails.

The Level 0 prompt separately prohibits executable operational instructions and requires explicit UNKNOWN handling. Human review remains mandatory. More advanced semantic policy checks are a planned hardening layer; V1 does not claim that structural validation alone can detect every unsafe recommendation.

## Evidence improvements

The collector adds sanitized Git metadata:

- local deployment path;
- branch;
- HEAD SHA;
- normalized origin host/path/repository;
- never the raw remote URL or embedded credentials.

Docker safe inspect also records configuration posture fields such as configured user, privileged mode, capability additions/drops, security options and read-only-rootfs status. These are configuration facts, not proof of effective runtime process identity.

## Efficiency objective

V0 used 31 model turns and more than one million cumulative input tokens.

V1 target:

- one model request;
- compact normalized evidence;
- no repeated model file reads/writes;
- bounded structured output;
- deterministic report generation.

The target is an order-of-magnitude reduction in model-token use while improving factual consistency.

## Autonomy status

V1 does **not** promote Atlas.Dev-00.

Current authority remains **Level 0 — Observe / Recommend**.

A successful V1 evaluation is evidence toward, not automatic approval for, Level 1.
