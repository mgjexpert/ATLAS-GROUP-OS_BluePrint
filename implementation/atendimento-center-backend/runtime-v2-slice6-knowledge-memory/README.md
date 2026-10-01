# Atlas Intelligence Runtime V2 — Slice 6: Knowledge + Operational Memory

This slice introduces durable knowledge without reusing Relationship Memory as a generic store.

## Boundaries

- Relationship Memory: person/contact continuity, unchanged.
- Organization Knowledge: durable documents/chunks in `knowledge.*`.
- Project Operational Memory: curated project facts in `portfolio.project_memories`.
- Run working context: remains `ai.runtime_runs.state`.
- Agent Pack Knowledge: later binds approved knowledge to versioned packs.

## Retrieval

V1 uses PostgreSQL full-text search with the `simple` configuration.

No embedding provider or vector dimension is hard-coded. Embeddings can be added later as a retrieval accelerator after the canonical source/chunk model is proven.

## API

- `POST /api/v1/group-os/knowledge/documents`
- `GET /api/v1/group-os/knowledge/search?q=...`
- `POST /api/v1/group-os/projects/:id/memory`
- `GET /api/v1/group-os/projects/:id/memory`

## Runtime tool

`atlas.knowledge.search`

Read-only, low-risk, capability `knowledge.read`.

The model sees it only after an active ToolGrant exists.

## Ingestion

Text is normalized and deterministically chunked by trusted application code. A SHA-256 fingerprint provides idempotent document ingestion. The LLM does not write durable knowledge directly.
