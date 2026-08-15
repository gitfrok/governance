# T-0038: Residency Declare wire surface — residency/v1, control-plane implementation, PDP binding

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-20 (residency Declare and placement hardening)
- **Repo(s):** governance (additive `contracts/proto/residency/v1`), backend (control-plane service
  and PDP binding) — ADR-0027 order, one commit per repo
- **Spec:** docs/specs/SPEC-0043-residency-declare-surface.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0063, 0062, 0006, 0009, 0011, 0060
- **Owner:** unassigned

## Goal

Give PR-22's declaration its operator handle: an additive `residency/v1` admin gRPC surface where
operators declare and replace per tenant, the PDP decides `residency.declaration.set` (already
owner-only and tenant-scoped in bundle 0.9.0), every act appends exactly one immutable audit record,
and the agent channel is never a declaration path (ADR-0063). This closes T-0033's recorded limit:
*Declare has no wire/RPC surface in Phase 3; the declaration is set by in-process composition only.*

## Acceptance criteria (test-first)

SPEC-0043 AC1 and AC5 (AC2–AC4 are T-0039's):
- [ ] AC1: an operator sets or replaces a tenant's declaration through the control-plane admin gRPC
      surface in `residency/v1`; the surface is a PEP that asks the PDP action
      `residency.declaration.set` and refuses coarsely when refused; a replace appends a new
      effective-dated declaration and retains history; every declaration, replacement and refusal
      appends exactly one immutable audit record naming tenant, actor, previous and new pinning, and
      effective time.
- [ ] AC5: no agent-channel declaration path exists — a wire tripwire test asserts that no message,
      field or path in `contracts/proto/agent/v1` can set, mutate or influence a residency
      declaration; `agent/v1` gains nothing.

## Tests to write first

Per SPEC-0043 § Test plan:
- contract: `buf lint` and `buf breaking` over `contracts/` — the new package is additive by
  construction, following the house pattern of `agent/v1`, `usage/v1` and `audit/v1` (AC1).
- PDP decision tests for `residency.declaration.set`, including the deny path and the coarse-refusal
  shape; audit-record assertions for allow, replace and refuse (AC1).
- wire tripwire test over the generated `agent/v1` descriptors (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — the change touches `contracts/` and an
authorization surface, so no tier below `full` is available (SPEC-0012).

Gate matrix (per repo):
- governance: `buf lint` + `buf breaking` on `contracts/` (additive-only within v1), `check-policies.sh`,
  `check-docs.sh`.
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.

## Notes / open questions

Depends on T-0037: SPEC-0043's assumption is that the durable declaration store lands with or before
this surface. No new role, grant or bypass beside the existing owner-only action; if a distinct
operator role is later needed, that is a policy change, not a surface change. Refusals keep the same
coarse shape as a nonexistent record — no surface error distinguishes tenants (SPEC-0001's rule).
