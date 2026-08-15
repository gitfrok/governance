# SPEC-0043: Residency Declare surface and placement hardening

- **Status:** Approved (2026-08-15; **amended 2026-08-15 after the Phase 3.1 plan review** — AC6 requires a verified caller, applying ADR-0045 rather than inheriting SPEC-0002's recorded limit (d); AC7 adds the platform-operator declare path per ADR-0067, Accepted the same day)
- **Owner:** platform
- **Context(s):** Control plane (declares, enforces, evidences) · Agent (reports witnessed placement only) — ADR-0022
- **ADRs:** 0063 (decides the surface), 0062 (durable declaration store), 0006 (PDP decides, surfaces ask), 0046 (tenant-scoped platform-operator principal — AC7's model), 0067 (extends that role to this action — AC7), 0045 (verified claims → tenant-scoped principal; caller input never chooses tenant/actor/roles), 0043 (credential verification through a narrow gateway), 0009, 0011, 0060
- **Task(s):** T-0038 (AC1, AC5, AC6, AC7), T-0039 (AC2, AC3, AC4)

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
- PDP enforcement of `residency.declaration.set` for the tenant's owner and for a tenant-scoped
  platform operator (ADR-0067); the audit record per act, including refusals, naming which principal
  acted.
- Declaration-versus-witnessed-placement contradiction rendering in the pack and as a health finding.
- Placement silence rendering as `GAP_REASON_PLACEMENT_SILENT` gaps.
- PlacementGate refusal for undeclared or unavailable targets.
- The tripwire that keeps any declaration path off the agent channel.

## Out of scope

- Declare over the agent channel and per-plane self-declaration (both rejected by ADR-0063).
- Any new role or bypass. AC7 adds no role: it reuses ADR-0046's existing `platform_operator`
  principal and adds exactly one action to it (ADR-0067). A cross-tenant path, a `tenant_id`
  request field, and a global operator identity that bypasses the PDP all stay out of scope
  (ADR-0067's rejected alternatives).
- Residency migration of existing data (SPEC-0040's open question, unchanged).
- Changes to PlacementGate enrolment-refusal semantics as shipped in Phase 3.
- Inbound paths of any kind (Phase 3.1 non-goal).

## Contracts touched

`contracts/proto/residency/v1` — **new versioned package, additive by construction** (ADR-0063
decision 1): a named admin service for the residency module, following the house pattern of
`agent/v1`, `usage/v1` and `audit/v1`. `agent/v1` gains nothing — no message, no field, no path
carrying a declaration.

**No message in the new package carries a tenant, actor or role field.** The subject is the verified
principal on the call (AC6), so a field for it would be a field for asserting it; the tenant a
declaration applies to is the one the verified principal is scoped to. A vendor operating on a
tenant's behalf is answered by *who the principal is* — ADR-0046's tenant-scoped platform operator,
extended to this action by ADR-0067 (AC7) — never by a field naming the tenant, which would
be an unauthenticated routing claim (ADR-0045). A contract test asserts the absence, so the field
cannot reappear as a convenience later.

## Data owned

The residency module owns the declaration (durable and effective-dated per ADR-0062/SPEC-0042) and
the surface that changes it. Audit owns the per-act records. The data plane owns nothing but witnessed
placement facts, reported over the channel that already exists.

## Acceptance criteria (each becomes a test)

- [ ] AC1: An operator sets or replaces a tenant's declaration through the control-plane admin gRPC
  surface in `residency/v1`. The surface is a PEP: it asks the PDP action
  `residency.declaration.set` — owner-only in bundle 0.9.0, gaining the platform-operator grant under
  AC7 — and refuses coarsely when refused. A replace appends a new effective-dated declaration and retains history.
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
- [ ] AC6: The surface refuses a caller it has not verified, before the PDP is asked. Tenant, actor
  and roles come from a verified principal (ADR-0045: one verified identity source; browser or client
  input never chooses tenant, actor, roles or outcome), established through the existing credential
  verification path (ADR-0043) and carried in the request context — never read from the request body.
  Three things are tested: a call with no verified principal is refused coarsely and audited, with no
  PDP decision recorded for an unverified subject; a call whose body carries a tenant, actor or role
  field is refused rather than believed (and no such field exists in the `residency/v1` messages —
  see § Contracts touched); and the audit record of AC1 names the **verified** actor, so the record
  and the enforcement cannot disagree. SPEC-0002's recorded limit (d) — doors that take tenant, actor
  and roles off the wire — describes the Phase-2 doors and is **not** extended to this one: a surface
  that writes control state does not inherit a posture where the subject is the caller's assertion.
- [ ] AC7: A verified,
  tenant-scoped `platform_operator` principal (ADR-0046: platform-administered binding, unreachable
  from tenant membership or any request field) may set or replace the declaration of the tenant it is
  bound to, alongside the owner grant which is unchanged. The PDP decides it as
  `residency.declaration.set` with the tenant-equality condition ADR-0046 decision 2 fixes — the
  principal's tenant equals the tenant declared about — so **no cross-tenant path and no `tenant_id`
  field exist**: AC6's prohibition holds unchanged, because the tenant is a property of the verified
  principal, not of the message. The audit record of AC1 distinguishes an owner declaration from a
  platform-operator one by verified actor and granted role, so a compliance reader can answer whether
  the customer chose the pinning or the vendor did. Tested: platform_operator allowed on its bound
  tenant; every non-owner tenant role denied; denied when the principal's tenant differs from the
  declared tenant; denied when the question is asked about any resource kind but the tenant; and the
  audit assertion above (ADR-0067).

## Test plan

- Contract gates: `buf lint` and `buf breaking` on `contracts/` — the new package is additive-only
  like every v1 addition (AC1).
- PDP decision tests for `residency.declaration.set`, including the deny path and the coarse-refusal
  shape; audit-record assertions for allow, replace and refuse (AC1). The same suite carries the
  platform-operator matrix — allowed on the bound tenant, denied for every non-owner tenant role,
  denied on tenant mismatch, denied on any other resource kind — plus the bundle-revision bump the
  grant requires (AC7).
- Contradiction/gap matrix domain tests: declared-matches, declared-contradicts,
  placement-silent-within-window, placement-silent-beyond-window — each rendering pinned to its pack
  section and health-finding vocabulary (AC2, AC3).
- Evidence-pack golden tests over the matrix, including the effective-dated change rendering
  (SPEC-0040 AC6) fed by the new surface.
- Wire tripwire test over the generated agent/v1 descriptors (AC5).
- Caller-verification tests (AC6): no principal → coarse refusal, audited, no PDP decision for an
  unverified subject; a body field claiming tenant/actor/role → refused, not believed; a descriptor
  test asserting `residency/v1` declares no tenant, actor or role field; and an audit assertion that
  the record names the verified actor, not a submitted one.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G2 Least privilege | the surface authorizes nothing itself; the PDP action decides about a **verified** subject and refusals are coarse (AC1, AC6). Who holds the grant is a policy question, not a surface one — the owner plus a tenant-scoped platform operator (AC7, ADR-0067), never a new bypass |
| G5 Auditability | one immutable record per declaration act, including refusals, with previous and new pinning, naming the verified actor (AC1, AC6) |
| G6 Compliance frameworks | contradictions and silent placement render in the pack with the existing vocabulary, not as inferred compliance (AC2, AC3) |
| G7 Data residency | enforcement gains its operator handle, and the authority split is tripwired (AC1, AC4, AC5) |

## Non-functional

- The detection window remains per-environment configuration, not a compiled-in constant
  (SPEC-0040 AC3).
- Refusals are the same coarse shape as a nonexistent record; no surface error distinguishes tenants
  (SPEC-0001's rule applied here).

## Open questions / assumptions

- **Who declares, resolved:** bundle 0.9.0 grants `residency.declaration.set` to the tenant's owner
  only, which the plan review found to be an unstated product decision rather than a settled one.
  ADR-0067 (Accepted 2026-08-15) decides it: the owner keeps the grant and a tenant-scoped platform
  operator gains it, with no cross-tenant path. Until the grant ships under T-0038 the bundle is still
  owner-only in fact, so a vendor onboarding flow before that point asks a tenant owner to declare.
- Assumed: SPEC-0042's durable declaration store lands with or before this surface — a wire surface
  over a volatile store would re-create the problem ADR-0062 exists to close.
- **AC6 fixes this surface, not the doors around it.** SPEC-0002's limit (d) stays open for the
  Phase-2 dataplane door and everything else served on it; the follow-up recorded there — door
  authentication plus a server-derived tenant-pinning interceptor — is unchanged by this spec. Open:
  whether the verification seam T-0038 builds for `residency/v1` is the one that later discharges
  limit (d) generally. If it is reused, that is a wider change than this spec approves and needs its
  own task; this spec neither promises it nor forecloses it.
- Assumed: an operator reaching this surface already has a credential the platform can verify
  (ADR-0043/ADR-0045 paths). If Phase 3.1 finds no such credential shape for a machine operator, that
  gap is named in T-0038's exit record — it is not a reason to accept a self-asserted caller.
