# Atlas Intelligence Runtime V2 — Slice 3: ApprovalEngine

Depends on:
- Runtime V2 Slice 1
- Runtime V2 Slice 2
- Group OS foundation schema

Purpose:

```text
side-effect ActionEnvelope
  -> PolicyEngine
  -> approval_required
  -> governance.approval_requests
  -> RuntimeAction = suspended
  -> human owner/admin decision
  -> policy re-check
  -> execute or deny
  -> durable audit
```

## Proof tool

`atlas.portfolio.update_task_status`

This is a reversible, medium-risk tool. It updates the status of a Group OS task inside the current organization.

The tool can never execute in Slice 3 without:
- active registration;
- active per-agent ToolGrant;
- approved durable ApprovalRequest;
- successful policy re-check immediately before execution.

## API

- `POST /api/v1/runtime/approvals/:id/decision`

Body:

```json
{
  "decision": "approved",
  "reason": "Approved for bounded task-state transition."
}
```

Allowed roles: `owner`, `admin`.

Denied or expired requests never execute.

## Security invariant

Human approval does not bypass policy.

Approval changes one input to policy evaluation from "not approved" to "approved request exists". Registration, grant, tenant, action identity, current status and tool policy are evaluated again before ToolRunner receives an allow decision.
