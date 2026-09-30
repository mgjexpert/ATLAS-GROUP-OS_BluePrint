# 04 — Model Routing & FinOps

## Policy

**Free-First / Premium-on-Demand.**

The objective is not "AI costs zero." The objective is to make paid inference the exception rather than the default where quality and reliability allow it.

## Routing hierarchy

```text
Task
 -> deterministic?
      -> yes: tool/workflow, no LLM if practical
      -> no: free model
              -> success: done
              -> fail/low confidence: second free model
                      -> fail/critical: premium model
```

## Current free-model strategy

The Agent Engine can route through OpenRouter and other providers.

Candidate free routes should be dynamically verified because model availability and limits change.

As of the architecture baseline, examples include free variants in the GLM/Kimi/Nemotron/Qwen ecosystem and OpenRouter's free router.

Never encode business reliability assumptions around a free endpoint without fallback.

## Model policy classes

- `free-only` — no paid fallback.
- `free-first` — default.
- `quality-first` — premium after one insufficient free attempt.
- `critical` — approved premium model from the start.

## Example role policies

- Atlas.Admin: free-only/free-first
- Atlas.Research: free-first
- Atlas.Content: free-first
- Atlas.Dev: free-first with premium fallback for difficult engineering
- Atlas.DG: free-first with premium fallback for strategic synthesis
- security/financially critical review: quality-first or critical

## FinOps record

Each inference/tool run should eventually attribute:
- organization;
- business unit;
- project;
- client;
- agent;
- task;
- provider;
- model;
- input tokens;
- output tokens;
- tool cost;
- infrastructure cost where measurable;
- total cost.

## Budgets

Every agent/team can receive:
- monthly budget;
- per-task budget;
- maximum premium spend;
- escalation threshold.

## Cost optimization principles

1. Do not use an LLM for deterministic operations.
2. Use n8n/workers for repeatable process execution.
3. Retrieve only relevant files/context.
4. Prefer cheap/free models for classification, formatting and routine synthesis.
5. Use stronger models for complex planning, difficult code, critical reviews and ambiguous reasoning.
6. Cache reusable results where safe.
7. Track cost by client and branch so services can be priced with margin.

## Future local inference

The Agent Engine already supports local/OpenAI-compatible routes.

Later options:
- Ollama;
- llama.cpp;
- vLLM/other serving.

Local inference is an optimization and privacy tool, not a prerequisite for Atlas V1.
