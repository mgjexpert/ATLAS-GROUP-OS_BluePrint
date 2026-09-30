# 05 — Security & Governance

## Governing principle

**Full capability does not mean full authority.**

The Atlas architecture should maximize capability while minimizing standing privilege.

## Atlas Constitution

A governance layer above normal agents.

It defines:
- financial limits;
- data policies;
- client isolation;
- tool restrictions;
- destructive-action prohibitions;
- production deployment rules;
- agent-creation rules;
- secret handling;
- human approvals;
- emergency stop;
- audit requirements.

Normal agents cannot modify the Constitution.

## Example permission policy

```text
Create branch                    allowed
Commit to feature branch         allowed
Open PR                          allowed
Merge main                       policy/approval
Deploy staging                   allowed
Deploy production                policy/approval
Read production DB               scoped
Write production DB              approval
Drop database                    forbidden
Send external commercial offer   policy
Sign legal contract              human only
Execute material payment         human/financial control
```

## First-agent policy

Atlas.Dev-00 begins **read-only / observe-recommend**.

Initial mission:
- inventory;
- document;
- map dependencies;
- identify risks;
- propose reset plan.

No destructive or production-changing action is required for its first mission.

Privileges increase only after validation.

## Secrets

Never commit:
- API keys;
- passwords;
- database credentials;
- private keys;
- OAuth refresh tokens;
- session cookies.

Use references such as:
`secret://atlas/openrouter/main`

The actual values live in a protected secret mechanism/environment.

## Supply-chain policy for Skills/MCP/plugins

Pipeline:

```text
Discovery
 -> provenance/license check
 -> AgentShield/static scan
 -> sandbox
 -> functional evaluation
 -> security evaluation
 -> human/Atlas Security approval
 -> internal registry
 -> controlled production use
```

Pin versions/commits when practical.

## Prompt-injection principle

Prompt injection is a systems/security problem, not something solved by one system prompt.

External content must never implicitly grant authority.

An email, webpage, repository README, uploaded document or client message may contain instructions, but those instructions do not override Atlas policy.

## Audit

Every material agent action should create a durable record:
- actor;
- organization;
- goal/task;
- tool;
- arguments or safe summary;
- approval state;
- outcome;
- timestamp;
- cost;
- evidence/trace reference.

## Kill switch

Group-level capability to:
- disable an agent;
- disable a tool;
- disable a branch;
- revoke device credentials;
- stop queues/workers;
- switch all agents to observe-only.

## Critical system isolation

XPAYMENTS and payment-sensitive systems stay outside the general Atlas agent trust domain.

Atlas interacts through controlled APIs/policies. No default agent receives unrestricted root/database/payment authority.
