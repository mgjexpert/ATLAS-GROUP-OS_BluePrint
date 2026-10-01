# Atlas Group OS — Agent Packs V1

Agent Packs are versioned operating bundles for Atlas roles.

A pack defines:
- role/mandate;
- instructions;
- model policy;
- capabilities;
- allowed tools;
- knowledge bindings;
- evaluation/approval state.

A pack is not an agent instance. A tenant Agent receives a specific approved pack version through an assignment.

## Runtime impact

An active assignment to an approved pack version can authorize tools listed as `allowed` in that version.

Manual `ToolGrant` remains supported. Runtime authorization is:

```text
registered + enabled tool
AND
(
  active explicit ToolGrant
  OR
  active AgentPackAssignment with approved pack version + allowed tool
)
```

Side-effect risk/approval policy still applies after authorization.

## V1 API

- GET/POST `/api/v1/group-os/agent-packs`
- POST `/api/v1/group-os/agent-packs/:id/versions`
- POST `/api/v1/group-os/agent-pack-versions/:id/approve`
- POST `/api/v1/group-os/agent-pack-versions/:id/tools`
- POST `/api/v1/group-os/agents/:agentId/pack-assignment`
- GET `/api/v1/group-os/agents/:agentId/pack-assignment`

Only approved pack versions can be assigned.

V1 does not silently overwrite an existing Agent systemPrompt/model. Agent provisioning from packs arrives in the next layer.
