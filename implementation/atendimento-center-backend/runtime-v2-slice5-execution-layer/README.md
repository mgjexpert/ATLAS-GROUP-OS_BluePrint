# Atlas Intelligence Runtime V2 — Slice 5: Execution Layer

This slice introduces the first durable BullMQ execution path while preserving the synchronous Runtime V2 API.

Flow:

POST /api/v1/runtime/jobs
-> create ai.execution_jobs row
-> BullMQ payload containing only executionJobId
-> atlas_agent_worker
-> reload canonical job + tenant from PostgreSQL
-> RuntimeRunService.start(...)
-> persist runId/result

Initial queue: atlas.agent

Redis uses ATLAS_REDIS_URL and should use a dedicated logical DB, for example /2. Existing Chatwoot DB 0 and Evolution DB 1 are not reused.

The first worker defaults to concurrency 1. Queue-level retries remain at 1 in this slice to avoid duplicate RuntimeRuns before run pre-allocation/idempotency is added.

Next hardening: pre-allocate RuntimeRun before enqueue, then enable safe retries and idempotency.
