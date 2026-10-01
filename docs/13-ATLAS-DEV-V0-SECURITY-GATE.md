# Atlas.Dev-00 V0 Security Gate — 2026-10-01

## Decision

**GO for engine smoke test.**  
**GO for first mission only with strict MCP disabled-by-default policy.**

## AgentShield summary

The initial scan reported a low aggregate score because it recursively inspected the installed ECC marketplace/cache and documentation tree.

Observed classifications:
- 5,014 total findings;
- 4 active-runtime;
- 2,137 docs-example;
- 2,445 plugin-cache;
- 118 template-example;
- 24 plugin-manifest;
- 7 hook-code;
- 279 unknown.

The four active-runtime findings were:
- two duplicate **medium** findings: ECC `chrome-devtools` MCP uses `npx -y`;
- two duplicate **info** findings: the same MCP lacks a description.

No critical/high findings were present in:
- active-runtime;
- hook-code;
- plugin-manifest.

Many apparent secret findings originated in ECC cache/lockfile material and were not treated as Atlas runtime credentials.

## Mitigation

The first mission does not require MCP.

Atlas.Dev-00 V0 therefore:
- requires Claude Code support for `--strict-mcp-config`;
- requires support for `--mcp-config`;
- supplies an explicit empty MCP config;
- fails closed if those flags are unavailable;
- forbids MCP use in the mission policy;
- keeps `ECC_HOOKS_ENABLED=false`;
- runs as `atlas-agent` without sudo/docker membership;
- disallows Bash, Edit, WebFetch and WebSearch;
- reads only sanitized evidence and the canonical blueprint;
- writes mission deliverables only to the mission output directory by policy.

## Residual risk

The Claude harness still has the Write tool because the mission must create deliverables. Filesystem path enforcement is not yet a full OS sandbox; the service-account boundary and file ownership limit blast radius.

A stronger filesystem sandbox is a post-V0 hardening item.

## Gate outcome

The remaining active AgentShield finding is mitigated by disabling all MCP servers during V0.

Proceed to:
1. start FCC locally on 127.0.0.1:8082;
2. verify service health/listener;
3. run one no-tools model smoke test through Claude Code -> FCC -> OpenRouter;
4. only after successful smoke test, launch Atlas.Dev-00 first mission.
