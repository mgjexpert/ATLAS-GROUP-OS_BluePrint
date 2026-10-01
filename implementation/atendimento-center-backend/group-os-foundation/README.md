# Atlas Group OS Foundation — Data Model Overlay

Target upstream: `nexflowx-hub/atendimento.center-backend`

Pinned upstream baseline:
`f47dc6a31db118e0047decd1ea50e6a97a30df48`

Purpose:
introduce the minimum canonical enterprise/control-plane entities required by Atlas Group OS without replacing the existing Tenant/CRM/Relationship Engine models.

## Hierarchy

```text
Organization
  -> BusinessUnit
      -> Branch
          -> Team
              -> Human / Agent
```

## Work graph

```text
Project
  -> Goal
      -> Task
          -> Run / Action / Approval
```

## Governance

```text
Policy
  -> ApprovalRequest
      -> ApprovalDecision

Decision
  -> durable board/operational decision record
```

## FinOps

```text
CostCenter
  -> Budget
  -> UsageRecord
```

This foundation deliberately does not implement accounting, payroll, legal corporate records or unrestricted payment execution.

## New schemas

- `portfolio`
- `governance`
- `finops`

Existing `core` receives BusinessUnit, Branch, Team and TeamMembership.

## Files

- `database/migrations/20261001_atlas_group_os_foundation_v1.sql`
- `prisma/group-os-models.prisma`
- `patches/prisma-datasource.patch`

## Integration

Apply the SQL migration through the Atlas Platform controlled migration process, then add the new schemas to the Prisma datasource and append the Prisma models. Run `npm run prisma:generate` and `npm run build` before deployment.

Runtime V2 may be deployed independently from this schema overlay. The two are designed to converge through Project/Goal/Task references in later slices.
