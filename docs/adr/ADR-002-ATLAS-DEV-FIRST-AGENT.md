# ADR-002 — Atlas.Dev-00 Is the First Operational Agent

**Status:** Accepted  
**Date:** 2026-09-30

## Context

The Group needs both executive management agents and technical agents.

The existing infrastructure must first be understood and reorganized before the Group OS can safely manage it.

## Decision

Deploy **Atlas.Dev-00 / Founding Engineer** before Atlas.DG receives broad operational responsibility.

Atlas.Dev-00 starts at autonomy level L1/L2:
- observe;
- analyze;
- document;
- recommend.

Its first mission is a non-destructive infrastructure and portfolio inventory.

## Rationale

A technical first agent can establish reliable ground truth about:
- VPS;
- Docker;
- networks;
- data stores;
- repos;
- deployments;
- domains;
- dependencies;
- resource usage;
- backup posture.

Atlas.DG becomes useful once this ground truth and Group OS data model exist.

## Promotion criteria

Atlas.Dev may receive controlled write privileges only after:
- inventory review;
- security review;
- backup verification;
- policy implementation;
- audit logging;
- human approval.
