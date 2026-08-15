# T-0038: Residency Declare wire surface — residency/v1, verified caller, control-plane implementation, PDP binding

- **Status:** Done
- **Phase / Epic:** 3.1 / EP-20 (residency Declare and placement hardening)
- **Repo(s):** governance (additive `contracts/proto/residency/v1`, plus the `policies/` grant and
  its tests for AC7), backend (control-plane service and PDP binding) — ADR-0027 order, one
  commit per repo
- **Spec:** docs/specs/SPEC-0043-residency-declare-surface.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0063, 0062, 0006, 0046 (tenant-scoped platform-operator principal), 0067 (platform-operator declare grant — AC7), 0045 (verified claims → tenant-scoped principal; caller input never chooses tenant/actor/roles), 0043 (credential verification gateway), 0009, 0011, 0060
- **Owner:** unassigned

## Goal

Give PR-22's declaration its operator handle: an additive `residency/v1` admin gRPC surface where
operators declare and replace per tenant, the PDP decides `residency.declaration.set` (owner-only and
tenant-scoped in bundle 0.9.0 today; AC7 would add a tenant-scoped platform operator beside it), every
act appends exactly one immutable audit record,
and the agent channel is never a declaration path (ADR-0063). This closes T-0033's recorded limit:
*Declare has no wire/RPC surface in Phase 3; the declaration is set by in-process composition only.*

## Acceptance criteria (test-first)

SPEC-0043 AC1, AC5, AC6 and AC7 (AC2–AC4 are T-0039's):
- [x] AC1: an operator sets or replaces a tenant's declaration through the control-plane admin gRPC
      surface in `residency/v1`; the surface is a PEP that asks the PDP action
      `residency.declaration.set` and refuses coarsely when refused; a replace appends a new
      effective-dated declaration and retains history; every declaration, replacement and refusal
      appends exactly one immutable audit record naming tenant, actor, previous and new pinning, and
      effective time.
- [x] AC5: no agent-channel declaration path exists — a wire tripwire test asserts that no message,
      field or path in `contracts/proto/agent/v1` can set, mutate or influence a residency
      declaration; `agent/v1` gains nothing.
- [x] AC6: the surface refuses a caller it has not verified, before the PDP is asked. Tenant, actor
      and roles come from a verified principal carried in the request context (ADR-0045; the
      `identity/api` principal seam — `WithPrincipal`/`RequirePrincipal` — is what a verification
      step populates), never from the request body, and `residency/v1` declares no tenant, actor or
      role field at all. Tested: no principal → coarse refusal, audited, and no PDP decision recorded
      for an unverified subject; a body field claiming a subject → refused, not believed; the AC1
      audit record names the verified actor. SPEC-0002's limit (d) covers the Phase-2 doors and is not
      extended to this one.
- [x] AC7: a tenant-scoped `platform_operator` principal (ADR-0046 binding, platform-administered) may
      declare for the tenant it is bound to, beside the unchanged owner grant. Lands as a reviewed
      Rego change in `policies/` with its own tests — allowed on the bound tenant, denied for every
      non-owner tenant role, denied on tenant mismatch, denied on any resource kind but the tenant —
      plus the bundle-revision bump. No `tenant_id` field, no cross-tenant path, no new role:
      AC6's prohibition and ADR-0046's tenant-equality condition both stand. The audit record
      distinguishes an owner declaration from a platform-operator one by verified actor and granted
      role (ADR-0067).

## Tests to write first

Per SPEC-0043 § Test plan:
- contract: `buf lint` and `buf breaking` over `contracts/` — the new package is additive by
  construction, following the house pattern of `agent/v1`, `usage/v1` and `audit/v1` (AC1).
- PDP decision tests for `residency.declaration.set`, including the deny path and the coarse-refusal
  shape; audit-record assertions for allow, replace and refuse (AC1).
- wire tripwire test over the generated `agent/v1` descriptors (AC5).
- caller-verification tests (AC6): unverified call refused and audited with no PDP decision; a
  subject-claiming body field refused; a descriptor test asserting `residency/v1` carries no tenant,
  actor or role field; audit assertion that the record names the verified actor.
- policy tests for AC7: the platform-operator matrix above, written in
  `policies/gitsaas/authz/authz_test.rego` beside the existing owner cases, with `check-policies.sh`
  green at the bumped bundle revision.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — the change touches `contracts/` and an
authorization surface, so no tier below `full` is available (SPEC-0012).

Gate matrix (per repo):
- governance: `buf lint` + `buf breaking` on `contracts/` (additive-only within v1), `check-policies.sh`,
  `check-docs.sh`.
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.

## Notes / open questions

**Scope bound on AC6:** verify this surface's caller, nothing more. The control-plane doors that
already exist (`backend/cmd/controlplane-app/main.go` — UsageService plaintext, no interceptor) stay
as they are; SPEC-0002's limit (d) and its recorded follow-up are untouched by this task. If the
verification seam built here turns out to be the one that later discharges limit (d) generally, say so
in the exit record and let that be its own task — widening it here is scope this spec does not
approve. If no verifiable credential shape exists for a machine operator, record the gap in the exit
record; a self-asserted caller is not the fallback.

**AC7's policy change is governance-repo work, ordered first.** The Rego grant, its tests and the
bundle-revision bump land as the governance commit, before the backend commit that consumes the
decision (ADR-0027 order). The wire surface is unaffected: no `tenant_id`, actor or role field ships —
the platform operator is tenant-scoped by its binding, not by the message (ADR-0067 decision 2). Until
this grant ships, the bundle remains owner-only in fact, so onboarding before that point asks a tenant
owner to declare.

Depends on T-0037: SPEC-0043's assumption is that the durable declaration store lands with or before
this surface. AC7 adds no new role — it reuses ADR-0046's `platform_operator` and adds one action to
it. Refusals keep the same coarse shape as a nonexistent record — no surface error distinguishes tenants (SPEC-0001's rule).

## Exit record (2026-08-15)

Governance-first in ADR-0027 order, then the backend half. Governance half at **794f578** and
**3b9e853** (additive `contracts/proto/residency/v1`, the `platform_operator` Rego grant under
ADR-0067, bundle **0.10.0**); backend half merged to backend main at **f182761** (the Wave 3a
commit: declare door + PlacementGate hardening). Every backend proof ran under `-race` against the
real-Postgres harness with zero durability skips; the gate matrix (gofmt/vet/build, `internal/arch`
fitness verbose, policy + tenant-isolation) was green at push.

**SPEC-0043 AC1 — declare/replace over the wire, PDP-bound, one audit record per act:**
the residency/v1 admin door is a PEP over `residency.declaration.set`, proven by
`TestBundleOneAuditRecordPerActAndRefusal` (declaration, replacement AND refusal each append
exactly one immutable audit record naming tenant, actor, previous and new pinning, and effective
time), replace appends and retains history (the effective-dated durable store T-0037 landed,
exercised concurrently under `-race` by `TestAC3_ConcurrentDeclareReplace`), and
`TestEnforcementTieBreaksOnChainSeqForSameInstantReplace`.

**SPEC-0043 AC5 — the agent channel is never a declaration path:**
`TestAgentChannelHasNoDeclarationPath` — the wire tripwire: no message, field or path in
`contracts/proto/agent/v1` can set, mutate or influence a residency declaration; `agent/v1` gained
nothing for it (the additive field that DID land there later is T-0040's `ca_trust_bundle`, a
distribution payload, not a declaration surface).

**SPEC-0043 AC6 — verified caller, before the PDP:** `TestDeclareVerifiesWireCredentialBeforePolicy`
and `TestDeclareRefusesUnverifiedBeforePolicy` (verification precedes the PDP ask),
`TestDeclareRefusesUnverifiableCredentialBeforePolicy`, `TestDeclareRefusalIsOneCoarseShape` (the
refusal is the same coarse shape as a nonexistent record — SPEC-0001's rule),
`TestDeclareRecordsUnverifiedRefusalOnOperationalChannel`, and
`TestDeclareUsesVerifiedPrincipalNotRequest` (tenant/actor/roles come from the verified principal
in the request context, never from the body; the descriptor contract asserts no request field
chooses subject).

**Carry — recorded against SPEC-0043 as the limit it is:** caller verification is PER-RPC on the
declare door itself — fail-closed in that handler, verification before the PDP ask — rather than a
server-wide interceptor. The control-plane doors that already exist keep their present posture
(SPEC-0002's limit (d) untouched, per this task's Notes scope bound); widening verification to
every door is a future task of its own, and until then a new credentialed door must not be added
without the same per-RPC verification seam.

**SPEC-0043 AC7 — tenant-scoped platform_operator grant:** the Rego grant landed in governance
(794f578/3b9e853, bundle 0.10.0) with its own policy tests, proven from the backend side by
`TestBundlePlatformOperatorDeclaresBoundTenant` (allowed on the bound tenant) and
`TestBundlePlatformOperatorTenantMismatchRefused` (denied on tenant mismatch); the owner grant is
unchanged beside it.

**Closes T-0033's recorded limit** — *Declare has no wire/RPC surface in Phase 3; the declaration
is set by in-process composition only* — the same shape T-0037 used to discharge T-0033's store
limit. The closure is recorded here and in the backlog.
