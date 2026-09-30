# ADR-001 — Initial Atlas Technology Composition

**Status:** Accepted as V0 architecture baseline  
**Date:** 2026-09-30

## Context

The project initially risked rebuilding a complete JARVIS/agent runtime from individual components.

Research showed mature existing projects already provide:
- agent harnesses;
- model routing;
- coding workflows;
- skills;
- agent teams;
- security scanning;
- design runtimes;
- swarm/federation concepts.

## Decision

1. Do not build a new generic agent harness in Atlas V1.
2. Use `atlashub-digital/claude-code` as the first Agent Engine/model gateway candidate.
3. Use Anthropic-style `SKILL.md` as the primary Atlas skill convention.
4. Pilot ECC as Atlas.Dev engineering operating layer.
5. Use AgentShield as an agent/skill/MCP security gate.
6. Adopt Karpathy-inspired simplicity/surgical/goal-driven rules in Atlas Engineering Constitution.
7. Treat Superpowers as complementary patterns, not a second mandatory engineering runtime.
8. Evaluate Ruflo and Claude Swarm later in Atlas Agent Lab for scale/federation.
9. Use OpenDesign as a candidate specialist runtime for creative production.
10. Keep proprietary Atlas Group OS/governance outside external engines.

## Consequences

Positive:
- faster implementation;
- lower engineering cost;
- replaceable agent engines;
- less duplicated open-source work;
- faster path to first autonomous agent.

Risks:
- multiple external dependencies;
- evolving APIs;
- license complexity;
- overlapping orchestration concepts.

Mitigation:
- adapters;
- pinned versions;
- Atlas Skill Registry;
- security evaluation;
- no proprietary core embedded in external forks without necessity.
