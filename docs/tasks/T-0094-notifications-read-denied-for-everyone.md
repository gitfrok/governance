# T-0094: Reading notifications is denied for every principal

- **Status:** Todo (filed 2026-09-23)
- **Phase / Epic:** EP-31 carry (notifications)
- **Repo(s):** **governance** (contract, additive), then **backend**, then **bff** — separate commits
  (invariant 23)
- **ADRs:** 0086 (notifications context), 0006 (deny-by-default PDP)
- **Owner:** unassigned

## What was measured

On the dev cluster, 2026-09-23, with a valid data-plane session (`tenant_id=dev`,
`actor_roles=[owner]`): `GET /v1/notifications` → `404 {"error":"unavailable"}`. Calling the data
plane directly — `gitsaas.notifications.v1.NotificationService/ListNotifications` with that tenant and
actor — answers `PermissionDenied: notifications unavailable`. The `notifications` tables exist.

## Why

`governance/policies/gitsaas/authz/authz.rego` grants `notification.read` through a role the subject
holds (`some role in input.subject.roles`). But `NotificationContext` carries only `tenant_id` and
`actor_id` — no roles — and `modules/notifications/internal/adapters/grpc/server.go` builds the PDP
subject without any. So the decision is always a deny, for everyone. The repository contracts carry
`actor_roles` in their context message, which is why the repository list works for the same session.

## Acceptance criteria

- [ ] AC1 `NotificationContext` gains the caller's roles, additively (contracts are additive-only in v1).
- [ ] AC2 The notifications server passes them to the PDP; a test fails today and passes after.
- [ ] AC3 The BFF forwards the session's roles, as it does for repositories.
- [ ] AC4 On the dev cluster, `GET /v1/notifications` answers `200` for a logged-in principal.

## Notes

EP-31 was recorded Done on 2026-08-21 with the bell, list and mark-read working end to end. Either
the policy grew its role requirement after that, or the end-to-end proof ran against a permissive
fake PDP. Establish which before fixing, so the gate that should have caught it is named.
