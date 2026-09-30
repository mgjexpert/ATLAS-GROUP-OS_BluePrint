# 01 — Technical Architecture

## High-level topology

```text
PDG / Humans
     |
ATLAS Command / Voice / Mobile / Edge
     |
Atlas Realtime + API Gateway
     |
ATLAS GROUP OS
|-- Identity & Organizations
|-- Governance & Approval
|-- Portfolio & Projects
|-- Clients / Contracts / Services
|-- Agent Registry & Workforce
|-- Budgets / FinOps / Cost Centers
|-- Memory / Knowledge / Decisions
|-- Audit / Traces / Incidents
     |
Atlas Agents
|-- Atlas.DG
|-- Atlas.Dev
|-- Atlas.Admin
|-- Atlas.Research
|-- Atlas.Content
|-- Atlas.Sales
|-- future roles
     |
Atlas Skills + Policies + Tool Registry
     |
Agent Engine / Specialist Runtimes
|-- atlashub-digital/claude-code
|-- ECC (engineering)
|-- OpenDesign (creative)
|-- future controlled runtimes
     |
Models / Providers
|-- OpenRouter free models
|-- OpenAI
|-- Anthropic / Google / others
|-- Ollama / local later
     |
Tools / Execution Systems
GitHub | Vercel | Supabase | Gmail | Drive | Calendar
Chatwoot | Evolution | n8n | Typebot | Docker | Browser | APIs
```

## Separation of responsibilities

### Group OS
Canonical source of truth for enterprise state.

It must not depend on a single model vendor or coding harness.

### Agent Engine
Executes agent sessions. The first candidate is `atlashub-digital/claude-code`, maintained as close to upstream as practical.

The Agent Engine is replaceable.

### Specialist runtimes
Used only where they provide meaningful domain leverage.

Examples:
- ECC for engineering process;
- OpenDesign for design/content production;
- later Ruflo components if swarm/federation proves valuable.

### Skills
Portable, versioned capabilities. Prefer a simple `SKILL.md` contract plus optional scripts, references and assets.

### Tools
Actions against external systems. Tools must be typed, permissioned and auditable.

### Workflows
Deterministic multi-step processes should prefer n8n or deterministic workers rather than consume LLM calls for every step.

## Existing Atlas Platform

The current Atendimento.Center backend already contains useful foundations:
- multi-tenant entities;
- agent entities and versions;
- relationship memory/state;
- conversations;
- agent runs/follow-ups;
- CRM and channels;
- Atlas Engage / Growth / Signals concepts.

Short term, Atlas Group OS may reuse these components.

Long term, Atlas Intelligence/Group OS boundaries should be explicit so home/device/personal capabilities are not structurally subordinated to a customer-support application.

## Realtime

Vercel/frontend may host UI, but device command/control and long-lived real-time connections should run on Atlas-controlled infrastructure.

Suggested transport:
- WebSocket for realtime command/event streams;
- HTTP APIs for normal operations;
- queues for async work;
- database/event log for durable state.

## Queue direction

Target queues:
- atlas.agent
- atlas.tools
- atlas.followups
- atlas.knowledge
- atlas.notifications
- atlas.integrations
- atlas.portfolio
- atlas.automation
- atlas.signals
- atlas.smm

Redis/BullMQ is a likely implementation target, but architecture must not force a premature migration of every current worker.

## Data

Canonical operational data:
- PostgreSQL/Supabase.

Knowledge:
- PostgreSQL + pgvector or another controlled retrieval layer.

Large artifacts:
- object storage.

Secrets:
- secret manager / protected environment configuration; never Git.

## Edge

Future Atlas Edge principles:
- outbound-only secure connection;
- device keypair and enrollment;
- per-device capability grants;
- no open inbound desktop port;
- explicit approval classes;
- complete audit;
- kill switch.

Prefer action methods in this order:
1. API
2. DOM/browser automation
3. OS accessibility APIs
4. vision
5. raw coordinates only as last resort.
