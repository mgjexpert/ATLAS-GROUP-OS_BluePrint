# 03 — Agent Engine, Skills & Specialist Runtimes

## Core rule

ATLAS should not rebuild agent harnesses, coding workflows or design runtimes that are already mature.

## Agent/model gateway

Primary candidate:
- https://github.com/atlashub-digital/claude-code

Role:
- connect multiple agent harnesses;
- route multiple model providers;
- provide sessions;
- support coding agents such as Claude Code, Codex, OpenCode, Hermes, Pi and others;
- support low-cost/free and local providers.

Atlas-specific IP should stay outside this fork when practical.

## Skill standard

Reference:
- https://github.com/anthropics/skills

Adopt the `SKILL.md` pattern as Atlas' primary portable skill convention.

Typical structure:

```text
skill-name/
  SKILL.md
  scripts/
  references/
  assets/
  tests/
```

Atlas extends the concept with registry metadata:
- provenance;
- license;
- version;
- security status;
- required tools;
- required secrets;
- permission class;
- evaluation score;
- approval status.

## ECC

Reference:
- https://github.com/affaan-m/ECC

Initial role:
**engineering operating system for Atlas.Dev**.

Relevant capabilities include specialized engineering agents, skills, hooks, memory, review, continuous learning and AgentShield integration.

Do not recreate those features in Atlas until a proven Atlas-specific requirement exists.

## AgentShield

Reference:
- https://github.com/affaan-m/agentshield

Use as an early security gate for:
- secrets;
- dangerous permissions;
- MCP configurations;
- hooks;
- prompt injection surfaces;
- supply-chain risks;
- unsafe agent files.

No downloaded community skill should move directly into production.

## Superpowers

Reference:
- https://github.com/obra/superpowers

Use as a complementary methodology/library, especially:
- brainstorming;
- implementation planning;
- worktrees;
- TDD;
- systematic debugging;
- review;
- verification.

Avoid installing overlapping mandatory workflows that create contradictory agent behavior. ECC will be the default V1 engineering methodology; selectively borrow Superpowers patterns only where they add value.

## Karpathy-inspired engineering rules

Reference:
- https://github.com/multica-ai/andrej-karpathy-skills

Adopt principles as Atlas Engineering Constitution:
1. think before coding;
2. simplicity first;
3. surgical changes;
4. goal-driven execution with verifiable success criteria.

## Ruflo

Reference:
- https://github.com/ruvnet/ruflo

Research lane, not V1 core.

Especially relevant later:
- swarm coordination;
- autonomous loops;
- background workers;
- goals;
- cost tracking;
- memory;
- agent federation across machines.

Test in an isolated Atlas Agent Lab before adopting.

## Claude Swarm

Reference:
- https://github.com/affaan-m/claude-swarm

Useful reference for:
- dependency-graph task decomposition;
- parallel agents;
- file-conflict controls;
- budget enforcement;
- quality gate;
- session replay.

Potential source of patterns for Atlas Task Graph.

## OpenDesign

Reference:
- https://github.com/nexu-io/open-design

Candidate specialist runtime for Atlas Creative / Content / Digital Factory.

Useful for:
- design systems;
- prototypes;
- slides;
- images;
- videos/motion;
- design skills;
- agent adapters.

## affaan-m/JARVIS

Reference:
- https://github.com/affaan-m/JARVIS

Not an ATLAS core candidate. Its product is person-intelligence/research using recognition and online enrichment.

Only study selected technical patterns:
- real-time streaming;
- voice WebSocket;
- parallel browser agents;
- live agent activity UI;
- graceful service degradation.

Do not adopt person-identification/enrichment functionality as an Atlas default capability.
