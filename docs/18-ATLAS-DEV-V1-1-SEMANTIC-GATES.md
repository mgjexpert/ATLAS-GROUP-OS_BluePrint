# Atlas.Dev V1.1 Semantic Evidence Gates

## Purpose

V1 proved the structural pipeline. Qualitative review then showed that schema-valid prose can still contain operationally material semantic errors.

V1.1 adds deterministic semantic checks derived from the evidence manifest. The goal is not to build a universal natural-language verifier; it is to turn repeated, objective failure modes into fail-closed gates.

## New deterministic evidence

The compact evidence manifest now includes:

- exact container count;
- exact Compose project count and names;
- container state counts;
- Docker network and volume counts;
- host-bound container list;
- per-container Docker port classification:
  - `host_bindings`;
  - `container_exposed_ports`;
- per-container hardening flags:
  - `no_new_privileges`;
  - `drops_all_capabilities`;
  - `read_only_rootfs`.

Evidence capability flags also state when the snapshot does **not** contain:

- dependency graph evidence;
- firewall policy;
- reverse-proxy routing intent;
- per-service resource usage;
- volume usage classification;
- secret values.

## Semantic fail-closed checks

The V1.1 validator rejects analysis when it detects supported classes of contradiction, including:

- executive container/project counts that contradict deterministic facts;
- claims that a container is host-published when it has no host binding;
- a stop action against a container whose current state is already stopped/exited;
- dependency-order claims when no dependency graph exists;
- right-sizing recommendations without per-service resource evidence;
- "unused volume" classification without volume-usage evidence;
- selected secret-value assertions when only variable-name evidence exists;
- reverse-proxy bind/interface remediation when routing intent evidence is unavailable.

These checks are intentionally conservative and are not a complete semantic proof system.

## Prompt hardening

The Level 0 prompt now explicitly requires:

- exact Docker port semantics;
- environment variable name/value distinction;
- container-specific hardening claims;
- current-state-aware recommendations;
- no dependency order inference from networks;
- no interface restriction recommendation for public reverse proxy binds without intent evidence;
- no right-sizing without measured per-service usage;
- no unused-volume classification without evidence;
- no speculative cause for an empty Git HEAD.

## Deterministic executive footprint

The materializer now places a deterministic footprint at the beginning of the executive summary:

- container count;
- running/stopped count;
- Compose project count;
- network count;
- volume count.

The model assessment remains a separate section and remains subject to validation/human review.

## Promotion impact

V1.1 remains Level 0.

A new evaluation must pass:

1. structural validation;
2. semantic validation;
3. qualitative human review with zero material factual errors.

Only then may Atlas.Dev-00 be considered a Level 1 candidate.
