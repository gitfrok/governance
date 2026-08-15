# ADR-0067: A tenant-scoped platform operator may set a tenant's residency declaration

- **Status:** Accepted (2026-08-15)
- **Deciders:** product/architecture
- **Supersedes / superseded by:** —
- **Related:** ADR-0046 (the platform-operator principal this extends — its decision 4 is why this is
  a decision and not a policy edit), ADR-0063 (the Declare surface), ADR-0045 (verified claims →
  tenant-scoped principal), ADR-0006 (PDP decides, surfaces ask), ADR-0042/ADR-0018 (the precedent
  that some acts are platform-controlled rather than tenant self-service), SPEC-0043, T-0038,
  policy bundle 0.9.0

## Context

SPEC-0043's Declare surface asks the PDP action `residency.declaration.set`, which policy bundle
0.9.0 grants to **owner** only. The Phase 3.1 plan review then asked the question the spec had not:
who is the operator that declares a tenant's residency? Two readings were live, and they need
different authority:

- **The tenant's own owner** — residency is the tenant's compliance decision, so the accountable
  principal inside the tenant makes it. This is what bundle 0.9.0 already implements.
- **A platform-side operator declaring on a tenant's behalf** — the vendor's staff pinning a tenant
  to a cloud and region, typically during onboarding, a contractual commitment, or an incident.

The second is not expressible today. It looks at first like a cross-tenant act needing a `tenant_id`
on the wire — which invariant 1 and ADR-0045 both refuse, because a request field naming the tenant
is a caller assertion about authority. **ADR-0046 already solved this shape** for replica
force-promotion: a verified, *tenant-scoped* `platform_operator` principal, bound to the tenant by a
platform-administered binding that tenant membership and browser input cannot create or modify, with
the PDP granting the action only when the principal's tenant equals the resource's tenant. No
cross-tenant request field, no global identity bypassing the PDP, and one immutable audit record
naming the verified actor.

So the mechanism exists. What does not exist is the authority to reuse it here: **ADR-0046
decision 4 deliberately confines that role to the recovery action** — *"This role authorizes only the
recovery action. It gives no repository read/write, tenant administration, credential, or
policy-authoring grant."* Adding a second action to `platform_operator` widens a role whose narrowness
was itself the decision. That is why this is an ADR rather than a policy-bundle edit, per ADR-0001 and
invariant 12 — it was filed Proposed and accepted the same day.

## Decision

**Extend the tenant-scoped `platform_operator` principal of ADR-0046 to `residency.declaration.set`,
under the same constraints that made it acceptable for force-promotion — and keep the owner grant.**

1. **Both principals may declare; neither replaces the other.** `residency.declaration.set` is
   granted to `owner` (unchanged, bundle 0.9.0) and to `platform_operator` (new). Residency is a
   compliance commitment that either the accountable tenant principal or the vendor operating on the
   tenant's behalf may record; a tenant that declares its own residency does not lose that ability
   because the vendor can also do it.
2. **Tenant-scoped, never cross-tenant.** The grant holds only where the principal's tenant equals
   the tenant the declaration is about — ADR-0046 decision 2's tenant-equality condition, unchanged.
   The binding that puts a platform operator in a tenant is platform-administered and unreachable
   from tenant membership management or any request field (ADR-0046 decision 1). **No `tenant_id`,
   actor or role field is added to `contracts/proto/residency/v1`**: SPEC-0043 AC6's prohibition
   stands exactly as written, because the tenant is a property of the verified principal, not of the
   message.
3. **One audit record, naming which principal acted.** The immutable record SPEC-0043 AC1 requires
   gains no new shape, but it must distinguish an owner declaration from a platform-operator
   declaration — the actor's verified identity and the role the decision was granted under. A
   compliance reader must be able to answer "did the customer choose this, or did we?" from the
   record alone.
4. **The role stays narrow.** This ADR adds exactly one action to `platform_operator`. It grants no
   repository access, no tenant administration, no credential issuance and no policy authoring —
   ADR-0046 decision 4's sentence survives with a second action named in it, not with its principle
   weakened. A third action is a third decision.
5. **Policy is where it lands.** The grant is a reviewed change to the Rego bundle with its own tests
   (allow platform_operator, deny every tenant role that is not owner, deny when principal tenant ≠
   resource tenant, deny when the resource is not the tenant), and it bumps the bundle revision —
   the bundle is versioned configuration (invariant 13, ADR-0006), so the policy change is reviewable
   on its own terms rather than implied by a service's code.

## Rejected alternatives

**A `tenant_id` field on the Declare request.** The obvious way to let one caller act on another
tenant, and the reason it is refused is the same reason ADR-0045 refuses browser-supplied tenant
scope: a request field naming the tenant is an unauthenticated routing claim that the PDP would then
decide about. It would also contradict SPEC-0043 AC6, which was added in the same review that raised
this question.

**A new `residency_operator` role.** A second platform-side role with one action. It duplicates
ADR-0046's binding machinery, its verification path and its audit shape for no distinction anyone can
act on, and the vocabulary review cost of a role is paid every time someone reads the policy.

**Platform-operator only, dropping the owner grant.** Makes residency vendor-controlled and takes a
compliance decision away from the accountable principal inside the tenant. PR-22 makes residency the
tenant's declaration; removing the tenant's ability to make it inverts that.

**Leave it owner-only and let the vendor act as a tenant owner.** Operationally tempting and exactly
the anti-pattern ADR-0046 exists to prevent: staff holding tenant-owner credentials makes every
subsequent audit record ambiguous about who acted, and grants far more than the one action needed.

## Consequences

- SPEC-0043 carries the platform-operator path as **AC7**, now unblocked, and T-0038 carries the
  policy change with its tests and the bundle-revision bump.
- The audit vocabulary must carry the acting role, so a residency declaration's provenance is
  answerable from the record (decision 3). If the existing record shape cannot express it, that is an
  additive change under its own governance PR.
- `platform_operator` becomes a two-action role. The follow-up ADR-0046 implies — what that role may
  and may not accumulate — becomes worth writing before a third action arrives, and is recorded as an
  open follow-up rather than decided here.
- Until the grant ships under T-0038, bundle 0.9.0 remains owner-only in fact: the decision is made,
  the policy is not yet changed, and a vendor onboarding flow before that point still asks a tenant
  owner to declare.
