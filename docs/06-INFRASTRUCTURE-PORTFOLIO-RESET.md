# 06 — Infrastructure & Portfolio Reset 2026

## Purpose

Before scaling Atlas, reduce operational noise and convert every existing project into a controlled asset.

## Atlas Reset sequence

```text
DISCOVER
 -> BACKUP
 -> DOCUMENT
 -> CLASSIFY
 -> FREEZE
 -> CONSOLIDATE
 -> REDUCE COST
 -> BUILD CORE
 -> REACTIVATE BY PRIORITY
```

## Project states

- ACTIVE
- REVIEW
- INCUBATION
- COLD
- ARCHIVED
- TERMINATED

"Cold" means recoverable, not abandoned.

## Recovery package

Before suspending a project preserve:

### Code
- repository;
- default branch;
- current commit SHA;
- tags/releases where relevant.

### Database
- schema/migrations;
- verified backup;
- restore procedure.

### Storage
- buckets;
- media;
- file inventory;
- external storage references.

### Infrastructure
- Dockerfiles;
- compose manifests;
- Vercel config;
- DNS map;
- webhooks.

### Configuration
- environment variable names;
- secret references only;
- external account IDs where non-secret.

### Documentation
- architecture;
- known issues;
- pending work;
- dependencies;
- recovery instructions.

## Initial portfolio hypothesis

The following is a starting classification for review, not a final investment decision.

### Core / remain active
- AtlasHub / Atlas Platform direction
- Atendimento.Center shared stack and reusable services
- ATLAS Group OS / Atlas Intelligence build
- XPAYMENTS — isolated critical infrastructure

### Place under formal review before further spend
- LeveLab
- FaceLove
- MyTrainX
- PiXBrasil
- AtlasWallet

The Atlas Executive/Strategy process may later recommend:
- continue;
- accelerate;
- merge;
- pivot;
- hold;
- archive;
- terminate.

The human Board/PDG decides material portfolio actions.

## Existing infrastructure leverage

Already-available resources include:
- domains;
- GitHub;
- Vercel;
- Supabase projects;
- OpenRouter/OpenAI access;
- VPS infrastructure;
- Docker;
- Chatwoot;
- Evolution;
- n8n;
- Typebot.

This means Atlas V1 should prioritize consolidation and orchestration before buying new infrastructure.

## VPS cost principle

Stopping containers only reduces resource consumption, not necessarily the fixed VPS bill.

Real savings come from:
- consolidating workloads;
- downsizing VPS resources when safe;
- cancelling redundant paid SaaS/services;
- suspending unnecessary managed databases;
- reducing duplicate deployments;
- reducing manual maintenance.

## Project Vault

Target structure for archived projects:

```text
project/
  manifest.yaml
  architecture.md
  recovery.md
  decisions.md
  dependencies.json
  infra/
  database/
  docs/
```

Large backups/artifacts belong in controlled storage, not normal Git history.
