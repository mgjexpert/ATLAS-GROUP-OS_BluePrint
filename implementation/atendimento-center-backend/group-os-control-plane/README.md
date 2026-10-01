# Atlas Group OS — Control Plane API Overlay

Depends on:
- Group OS foundation schema
- existing Atendimento.Center auth/tenant guards
- Runtime V2 may coexist but is not required for basic portfolio APIs

This overlay exposes the first operational control-plane surface:

- `GET /api/v1/group-os/structure`
- `GET /api/v1/group-os/projects`
- `GET /api/v1/group-os/projects/:id`
- `POST /api/v1/group-os/projects`
- `POST /api/v1/group-os/projects/:projectId/goals`
- `POST /api/v1/group-os/tasks`
- `PATCH /api/v1/group-os/tasks/:id/status`
- `POST /api/v1/group-os/decisions`
- `GET /api/v1/group-os/approvals`

All queries are organization-scoped through the authenticated Tenant. Mutating endpoints require owner/admin/supervisor roles. Approval decisions are intentionally not exposed in this overlay; ApprovalEngine will own that path later.
