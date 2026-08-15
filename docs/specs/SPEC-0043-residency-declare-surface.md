# SPEC-0043: Residency Declare surface and placement hardening

- **Status:** Approved (2026-08-15)
- **Owner:** platform
- **Context(s):** Control plane (declares, enforces, evidences) · Agent (reports witnessed placement only) — ADR-0022
- **ADRs:** 0063 (decides the surface), 0062 (durable declaration store), 0006 (PDP decides, surfaces ask), 0009, 0011, 0060
- **Task(s):** — (Phase 3.1, epic EP-20; task to be filed)

## Problem / context

PR-22 makes a tenant's residency declaration control-plane state, and Phase 3 implemented the state
but not the handle: `residency.declaration.set` exists as an owner-only, tenant-scoped PDP action in
policy bundle 0.9.0, the PlacementGate enforces the declaration at enrolment, and the evidence pack
cites it — yet T-0033's exit record carries the limit verbatim: *Declare has no wire/RPC surface in
Phase 3; the declaration is set by in-process composition only.* An operator who needs to declare or
change a tenant's pinned cloud/region has no surface to do it with.

ADR-0063 (Accepted) decides the handle: an additive `contracts/proto/residency/v1` admin service,
operators declare and replace, the PDP decides, every act is audited, and the agent channel is never
a declaration path. This spec fixes the wire surface, the contradiction and gap rendering that harden
placement evidence, and the tripwire that keeps the authority split true, for Phase 3.1 epic **EP-20**
(PR-22).

## In scope

- The residency/v1 admin gRPC surface: declare and replace, per tenant.
- PDP enforcement of `residency.declaration.set`; the audit record per act, including refusals.
- Declaration-versus-witnessed-placement contradiction rendering in the pack and as a health finding.
- Placement silence rendering as `GAP_REASON_PLACEMENT_SILENT` gaps.
- PlacementGate refusal for undeclared or unavailable targets.
- The tripwire that keeps any declaration path off the agent channel.

## Out of scope

- Declare over the agent channel and per-plane self-declaration (both rejected by ADR-0063).
- Any new role, grant or bypass beside the existing owner-only action.
- Residency migration of existing data (SPEC-0040's open question, unchanged).
- Changes to PlacementGate enrolment-refusal semantics as shipped in Phase 3.
- Inbound paths of any kind (Phase 3.1 non-goal).

## Contracts touched

`contracts/proto/residency/v1` — **new versioned package, additive by construction** (ADR-0063
decision 1): a named admin service for the residency module, following the house pattern of
`agent/v1`, `usage/v1` and `audit/v1`. `agent/v1` gains nothing — no message, no field, no path
carrying a declaration.

## Data owned

The residency module owns the declaration (durable and effective-dated per ADR-0062/SPEC-0042) and
the surface that changes it. Audit owns the per-act records. The data plane owns nothing but witnessed
placement facts, reported over the channel that already exists.

## Acceptance criteria (each becomes a test)

- [ ] AC1: An operator sets or replaces a tenant's declaration through the control-plane admin gRPC
  surface in `residency/v1`. The surface is a PEP: it asks the PDP action
  `residency.declaration.set`, already owner-only and tenant-scoped in bundle 0.9.0, and refuses
  coarsely when refused. A replace appends a new effective-dated declaration and retains history.
  Every declaration, replacement and refusal appends exactly one immutable audit record naming
  tenant, actor, previous and new pinning, and effective time.
- [ ] AC2: A declaration-versus-witnessed-placement contradiction is visible in the evidence pack's
  residency section and as a health finding, using the existing ResidencyFactKind vocabulary —
  `PLACEMENT_CONTRADICTION` within the configured detection window (SPEC-0040 AC3). Declare
  introduces no parallel error channel; `RESIDENCY_FACT_KIND_PINNING` remains a control-plane act and
  `PLACEMENT`/`PLACEMENT_REFUSED`/`PLACEMENT_CONTRADICTION` remain control-plane observations.
- [ ] AC3: Placement silence beyond the detection window renders as `GAP_REASON_PLACEMENT_SILENT`
  gaps in the pack's residency section — never as inferred placement. Absence of contradiction is
  not evidence of pinning (SPEC-0040 AC5's rule, with a named reason for the silent case).
- [ ] AC4: The PlacementGate refuses enrolment for an undeclared or unavailable target with the same
  coarse refusal shape as shipped, does not spend the token, and leaves an audit trail naming the
  declared and the attempted placement (SPEC-0040 AC2).
- [ ] AC5: No agent-channel declaration path exists. A wire tripwire test asserts that no message,
  field or path in `contracts/proto/agent/v1` can set, mutate or influence a residency declaration —
  the managed data plane never tells the control plane where it is allowed to run (SPEC-0040 AC1).

## Test plan

- Contract gates: `buf lint` and `buf breaking` on `contracts/` — the new package is additive-only
  like every v1 addition (AC1).
- PDP decision tests for `residency.declaration.set`, including the deny path and the coarse-refusal
  shape; audit-record assertions for allow, replace and refuse (AC1).
- Contradiction/gap matrix domain tests: declared-matches, declared-contradicts,
  placement-silent-within-window, placement-silent-beyond-window — each rendering pinned to its pack
  section and health-finding vocabulary (AC2, AC3).
- Evidence-pack golden tests over the matrix, including the effective-dated change rendering
  (SPEC-0040 AC6) fed by the new surface.
- Wire tripwire test over the generated agent/v1 descriptors (AC5).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G2 Least privilege | the surface authorizes nothing itself; the owner-only PDP action decides and refusals are coarse (AC1) |
| G5 Auditability | one immutable record per declaration act, including refusals, with previous and new pinning (AC1) |
| G6 Compliance frameworks | contradictions and silent placement render in the pack with the existing vocabulary, not as inferred compliance (AC2, AC3) |
| G7 Data residency | enforcement gains its operator handle, and the authority split is tripwired (AC1, AC4, AC5) |

## Non-functional

- The detection window remains per-environment configuration, not a compiled-in constant
  (SPEC-0040 AC3).
- Refusals are the same coarse shape as a nonexistent record; no surface error distinguishes tenants
  (SPEC-0001's rule applied here).

## Open questions / assumptions

- Assumed: bundle 0.9.0's `residency.declaration.set` grant set is complete for Phase 3.1 operators;
  if a distinct operator role is later needed, that is a policy change, not a surface change.
- Assumed: SPEC-0042's durable declaration store lands with or before this surface — a wire surface
  over a volatile store would re-create the problem ADR-0062 exists to close.
