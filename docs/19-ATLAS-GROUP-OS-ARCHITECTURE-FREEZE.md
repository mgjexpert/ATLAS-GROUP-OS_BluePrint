# Atlas Group OS — Architecture Freeze

Date: 2026-10-01
Status: **FROZEN FOR V2 IMPLEMENTATION**

## Decision

Atlas will not be built as a separate stack beside Atendimento.Center.

The current `nexflowx-hub/atendimento.center-backend` becomes the first control-plane implementation of **Atlas Platform / Atlas Group OS**.

A reusable runtime layer named **Atlas Intelligence** sits underneath product-specific surfaces and agent packs.

The architecture is:

```text
Humans / PDG / Operators
        |
        v
Atlas Command / Atendimento.Center / Product UIs / Channels
        |
        v
+-----------------------------+
|       ATLAS PLATFORM        |
|       Group OS / Control    |
|-----------------------------|
| Organization                |
| Business Unit / Branch      |
| Portfolio / Project         |
| Goal / Task / Decision      |
| Agent / Team / Skill        |
| Budget / Cost Center        |
| Policy / Approval           |
| Client / Contract / Service |
| Run / Trace / Audit         |
+-------------+---------------+
              |
              v
+-----------------------------+
|     ATLAS INTELLIGENCE      |
|        Runtime V2           |
|-----------------------------|
| ModelGateway                |
| AgentRuntime                |
| ActionEnvelope              |
| ToolRegistry                |
| PolicyEngine                |
| ApprovalEngine              |
| Run / Step / Trace          |
| Memory / Knowledge Access   |
+-------------+---------------+
              |
              v
Execution / Skills / Integrations / Queues
              |
              v
GitHub | Gmail | Drive | Calendar | CRM | Chatwoot
Evolution | Browser | APIs | Workers | Edge
```

## Existing foundation — REUSE

The current Atendimento.Center backend already contains useful canonical primitives.

### Core / tenancy

Reuse:

- `Organization`
- `Tenant`
- `TenantUser`
- `Entitlement`

### Agent registry

Reuse:

- `Agent`
- `AgentVersion`
- `AgentBinding`

The V2 registry must preserve versioned agent configuration and bindings while extending them with role, department/team, capability, policy, budget and evaluation metadata.

### Channels / conversations

Reuse:

- `ChannelAccount`
- `ConversationRef`
- `ContactIdentity`

Channel infrastructure remains an interface into Atlas; it is not the Atlas runtime itself.

### Relationship state / memory

Reuse as a specialized memory domain:

- `RelationshipState`
- `ConversationMemory`
- `ConversationSummary`
- `OpenLoop`
- `AgentWorldState`

Relationship Memory remains separate from organizational knowledge and operational project memory.

### Execution history

Reuse/evolve:

- `AgentRun`
- `AgentFollowup`
- `FlowRun`
- `AutomationRun`
- `AuditLog`

### Integration registry

Reuse:

- `IntegrationConnection`
- `WebhookEvent`

## Existing foundation — EVOLVE

### OpenRouterService -> ModelGateway

The current OpenRouter integration is a provider-specific completion client.

V2 replaces direct provider use inside agents with:

```text
AgentRuntime
    |
ModelGateway
    |
ModelProvider
    +-- OpenRouterProvider
    +-- OpenAIProvider
    +-- AnthropicProvider
    +-- GoogleProvider
    +-- LocalProvider (later)
```

No agent implementation should depend directly on OpenRouter/OpenAI/Anthropic SDK semantics.

### AgentRun -> Run / Step / Trace

Current `AgentRun` is relationship-runtime oriented.

V2 must support generic runs with:

- run status;
- initiating actor;
- organization/tenant;
- agent + agent version;
- goal/task reference;
- model/provider;
- token usage;
- cost;
- latency;
- steps;
- tool calls;
- approval checkpoints;
- artifacts;
- errors;
- final outcome;
- trace correlation.

### Worker loop -> Execution Layer

The current Atlas worker uses polling loops for SMM/signals jobs.

That remains valid for existing vertical services but is not the general Atlas agent execution model.

Target V2 queues:

- `atlas.agent`
- `atlas.tools`
- `atlas.followups`
- `atlas.knowledge`
- `atlas.notifications`
- `atlas.integrations`
- `atlas.portfolio`
- `atlas.automation`
- `atlas.signals`
- `atlas.smm`

Redis + BullMQ is the target implementation, introduced incrementally rather than by rewriting all existing workers at once.

## New Group OS domain — CREATE

The Group OS foundation adds canonical enterprise entities.

### Organization structure

```text
Organization
  -> BusinessUnit
      -> Branch
          -> Team
              -> Agent / Human
```

Required V2 entities:

- `BusinessUnit`
- `Branch`
- `Team`
- team memberships / reporting relationships

### Work / portfolio

Required:

- `Project`
- `Goal`
- `Task`
- `Decision`
- `Artifact`

Every material initiative should have owner, objective, current state, success criteria, dependencies, risk, budget/cost context and evidence.

### Governance

Required:

- `Policy`
- `ApprovalRequest`
- `ApprovalDecision`
- `PermissionGrant`
- `ActionClass`

Normal agents cannot change Atlas constitutional policy.

### Finance / operating control

Required:

- `Budget`
- `CostCenter`
- `UsageRecord`

This is operational/FinOps data, not a replacement for legal accounting.

### Tools

Required:

- `ToolDefinition`
- `ToolVersion`
- `ToolGrant`

Each tool requires:

- typed input/output;
- capability;
- risk class;
- side-effect classification;
- approval requirement;
- secret references;
- audit rules;
- timeout/retry policy.

## Canonical memory boundaries

Atlas uses five distinct scopes:

```text
PERSON        -> Relationship Memory
PROJECT       -> Operational Memory
ORGANIZATION  -> Knowledge
AGENT PACK    -> Approved Knowledge
RUN           -> Working Context
```

These stores must not collapse into one generic vector-memory bucket.

Authoritative structured business facts remain in domain tables/APIs.

## Canonical runtime flow

```text
Input / Event
    |
Identity + Tenant resolution
    |
AgentBinding resolution
    |
Policy pre-check
    |
Create Run
    |
Load Working Context
    |
AgentRuntime
    |
ModelGateway
    |
Planner / Tool Loop
    |
ActionEnvelope
    |
PolicyEngine
    |
ApprovalEngine (when required)
    |
ToolRunner / deterministic worker
    |
Verifier
    |
Writer / Response
    |
Memory candidates
    |
Memory policy + persistence
    |
Run/Step/Trace finalization
    |
Audit/Event
```

The model never directly executes a side effect. It proposes an `ActionEnvelope`; trusted runtime code decides whether execution is allowed.

## Product and agent-pack boundaries

Atlas Platform and Atlas Intelligence are shared.

Vertical/product behavior lives in Agent Packs and domain tools.

Initial packs:

- Atlas Executive
- Atlas.Dev
- Atlas Sales
- Micaela / FaceLove
- LIA / LeveLab
- MyTrainX Coach

A product may own its authoritative domain data while Atlas owns agent orchestration, conversation state, execution and governance.

## Deployment boundary

Target services:

```text
atlas-api
atlas-realtime
atlas-worker
atlas-signals-worker
```

These may initially share the existing Atendimento.Center repository/processes. Service separation should follow operational need, not architecture fashion.

## V2 implementation order

1. Architecture Freeze — this document.
2. Runtime V2 contracts.
3. ModelGateway.
4. Run / Step / Trace.
5. ToolRegistry + ActionEnvelope.
6. PolicyEngine + ApprovalEngine.
7. Execution Layer / BullMQ.
8. Knowledge + Memory.
9. Agent Packs.
10. Atlas Executive / Command surface.

Realtime/voice/Edge/computer-use are later interfaces and must not block the core runtime.

## Parallel infrastructure track

The Atlas HQ reset continues in parallel:

- recovery packages;
- Caddy extraction to shared edge;
- freeze of non-core applications;
- cost/disk cleanup only after recovery gates.

The Group OS implementation does not wait for that physical consolidation to finish.

## Frozen non-goals

For Runtime V2 we do **not**:

- build a new model vendor SDK abstraction per agent;
- make ECC the Atlas core runtime;
- make Claude Code the Group OS;
- import OpenJarvis/JARVIS as core;
- build swarm/federation first;
- build voice/Edge before the control plane;
- merge relationship memory with organizational knowledge;
- grant agents direct unrestricted side-effect authority.
