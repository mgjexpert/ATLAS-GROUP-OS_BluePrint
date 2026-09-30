# 10 — Research Sources & Component Strategy

This file records projects discussed during the architecture phase. Inclusion does not mean automatic adoption.

## Agent/model gateway

### atlashub-digital/claude-code
https://github.com/atlashub-digital/claude-code

Fork of Free Claude Code. Candidate Atlas Agent Engine/model-harness gateway.

Important: upstream currently declares AGPL terms. Atlas proprietary logic should remain separated and license obligations must be reviewed before SaaS distribution/modification decisions.

## Skill standard

### anthropics/skills
https://github.com/anthropics/skills

Primary reference for `SKILL.md` structure.

License status varies by skill. Some examples are Apache 2.0; some document-generation skills are source-available rather than open source. Review per component.

## Engineering

### affaan-m/ECC
https://github.com/affaan-m/ECC

MIT. Engineering system with agents, skills, hooks, memory, learning and security tooling. V1 candidate for Atlas.Dev.

### affaan-m/agentshield
https://github.com/affaan-m/agentshield

MIT. Security scanning for agent configurations, secrets, permissions, hooks, MCP and prompt-injection surfaces.

### obra/superpowers
https://github.com/obra/superpowers

MIT. Development methodology: brainstorming, planning, worktrees, TDD, subagent development, reviews and verification.

### multica-ai/andrej-karpathy-skills
https://github.com/multica-ai/andrej-karpathy-skills

Reference for engineering discipline: think before coding, simplicity, surgical changes, goal-driven verification.

### affaan-m/claude-swarm
https://github.com/affaan-m/claude-swarm

MIT. Reference for task decomposition, parallel agents, budgets, quality gate and session replay.

## Swarm / federation

### ruvnet/ruflo
https://github.com/ruvnet/ruflo

MIT. Research candidate for swarms, memory, background workers, goals, cost tracking and cross-machine agent federation.

Treat as a lab candidate first; avoid duplicating ECC/Atlas core responsibilities.

## Creative / design

### nexu-io/open-design
https://github.com/nexu-io/open-design

Apache-2.0 core with component-specific licenses. Candidate runtime for Atlas Creative/Content/Digital Factory.

## JARVIS reference

### affaan-m/JARVIS
https://github.com/affaan-m/JARVIS

Not a general JARVIS assistant; it is a person-intelligence/research application.

Study only selected realtime/streaming/voice/UI patterns. Do not make recognition/person-enrichment a default Atlas capability.

## Research rule

For every external component evaluate:
- fit;
- overlap;
- maturity;
- maintainability;
- license;
- security;
- data exposure;
- operating cost;
- lock-in;
- replacement path.

Prefer adapters and bounded integrations over deep forks.
