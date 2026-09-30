# ATLAS GROUP OS — Blueprint

**Status:** Architecture Baseline v0.1  
**Date:** 2026-09-30  
**Purpose:** master blueprint for the Atlas Group agentic enterprise.

ATLAS GROUP OS is conceived as an operating system for a company in which humans, AI agents, software services and autonomous business units work under one governance layer.

The human founder remains the **PDG / Chairman**. ATLAS is not intended to replace legal accountability or human governance. It provides the operating infrastructure through which the Group can plan, delegate, build, operate, monitor and scale.

## Core thesis

ATLAS is not another chatbot and not another coding agent.

The architecture separates:

- **ATLAS GROUP OS** — organization, governance, portfolio, clients, budgets, approvals, decisions and audit.
- **ATLAS** — personal/executive assistant and primary human interface.
- **ATLAS DG** — digital general-management role for Group operations.
- **ATLAS.DEV** — digital technology/engineering director.
- **Atlas Agent Engine** — execution layer using existing best-in-class agent harnesses.
- **Atlas Skills** — reusable capabilities based on the `SKILL.md` convention.
- **Atlas Tools** — typed connectors to GitHub, Vercel, Supabase, Gmail, Drive, Calendar, Chatwoot, Evolution, n8n, Typebot, Docker and other systems.
- **Atlas Edge / Voice / Command** — future real-time, device, voice and immersive interfaces.

## Architecture principle

Do not rebuild technology that already exists.

Use existing agent harnesses, skills ecosystems, design systems and orchestration frameworks where they are mature. Concentrate proprietary development on the Atlas organizational operating system, governance model, persistent enterprise memory, business-unit lifecycle and commercial platform.

## Initial stack decision

- Agent/model gateway candidate: `atlashub-digital/claude-code`
- Engineering operating layer: ECC
- Skill standard: Anthropic-style `SKILL.md`
- Security gate: AgentShield
- Engineering principles: Karpathy-inspired simplicity / surgical changes / goal-driven verification
- Complementary methodology: Superpowers, selectively
- Swarm/federation research: Ruflo and Claude Swarm
- Creative/design specialist runtime: OpenDesign
- Model strategy: Free-First / Premium-on-Demand
- Existing operations stack: Atendimento.Center + Chatwoot + Evolution + n8n + Typebot + Redis + PostgreSQL/Supabase
- Critical payments infrastructure such as XPAYMENTS remains isolated.

## Repository map

- `docs/00-VISION.md` — mission and product definition
- `docs/01-ARCHITECTURE.md` — technical architecture
- `docs/02-ORGANIZATION-OPERATING-MODEL.md` — Group, departments, branches and agent workforce
- `docs/03-AGENT-ENGINE-SKILLS.md` — agent engine, skills and external project strategy
- `docs/04-MODEL-ROUTING-FINOPS.md` — model routing and cost policy
- `docs/05-SECURITY-GOVERNANCE.md` — Constitution, permissions and safety
- `docs/06-INFRASTRUCTURE-PORTFOLIO-RESET.md` — Atlas Reset 2026 and project cold-storage model
- `docs/07-MONETIZATION-BUSINESS-MODEL.md` — SaaS, Managed Services and Venture Studio
- `docs/08-FIRST-AGENT-BOOTSTRAP.md` — first VPS agent implementation
- `docs/09-ROADMAP.md` — phased delivery
- `docs/10-RESEARCH-SOURCES.md` — repositories and research references
- `docs/adr/` — Architecture Decision Records
- `config/` — initial machine-readable policies and agent packs

## First operational milestone

Deploy **Atlas.Dev-00** as the Founding Engineer.

Its first mission is not to change production. It must inventory the Atlas VPS and ecosystem, create the infrastructure map, identify services and dependencies, calculate operational exposure/cost, and produce the **Atlas Reset 2026 Plan** for human approval.

After this baseline is verified, the system can progressively receive controlled write privileges.

---

This repository is the canonical architectural and governance source for ATLAS GROUP OS.
