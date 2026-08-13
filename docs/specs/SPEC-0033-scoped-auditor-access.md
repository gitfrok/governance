# SPEC-0033: Scoped, read-only, time-boxed auditor access

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Identity & Access, Policy (PDP), Audit
- **ADRs:** 0006, 0007, 0003, 0022, 0032
- **Task(s):** T-0027
- **PRD:** PR-18

## Problem / context

An external auditor must be able to read evidence and nothing else. Today the only way to show an
auditor a control is to give someone with repository access the job of exporting it, which is exactly
the engineer involvement PR-17 removes. PR-18 requires a **grant**: scoped to named evidence,
read-only, time-boxed, and conferring **no repository read**.

This is a distinct principal shape, not a role that happens to be able to read less. An auditor who
can enumerate repositories has already learned something the grant did not authorize.

## In scope

- An auditor grant: scoped to a tenant, a date range, and the packs within it; read-only; expiring
  without operator action.
- PDP enforcement of the grant, expressed in `governance/policies` (ADR-0006).
- Immutable audit of granting, using, expiring and revoking (ADR-0007).
- Immediate revocation semantics, reconciled with bundle-revision cache invalidation.
- Non-enumeration: an auditor cannot learn what exists outside the grant.

## Out of scope

- Pack generation and content (SPEC-0031/0032); this spec authorizes reading a pack, not producing it.
- Any write path — triage, policy authoring, approvals, imports — all denied to an auditor principal.
- Federated or external identity for auditors beyond what Identity & Access already provides
  (SPEC-0006, ADR-0045).
- Retention of the records a pack cites — the gate recorded in SPEC-0031.

## Data owned

Identity & Access owns auditor principals and grant records; Policy owns the rules that enforce them;
Audit owns the immutable records and the packs being read. No context reads another's tables
(ADR-0022).

## Revocation and cache invalidation

T-0027 requires revocation to take effect on the **next read**, not the next cache cycle. SPEC-0002
invalidates cached decisions by **bundle revision**, not by clock, so revocation must produce an
input change the decision path cannot miss: a grant's validity is a **server-derived fact supplied on
every decision request** — grant state and expiry read from Identity & Access at decision time — not
a claim baked into a cached decision or a token. A revoked or expired grant therefore fails the next
decision by construction, with no cache to wait out and no token to outlive it.

## Contracts touched

Additive on Identity & Access (`contracts/proto/identity/v1`): `CreateAuditorGrant`,
`RevokeAuditorGrant`, `ListAuditorGrants`, each with required verified context, tenant scoping, and
server-assigned versions. A grant carries an opaque ID, tenant, the evidence scope (date range,
optional repository scope, named packs), expiry, granting admin, auditor principal, and state. It
carries no repository permission, no role that implies one, and no renewal-on-use.

Additive events: `AuditorGrantIssued`, `AuditorGrantUsed`, `AuditorGrantRevoked`,
`AuditorGrantExpired` — opaque identifiers and scope only, never pack contents.

New Rego rules in `governance/policies`, adding this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `evidence.pack.read` | `evidence_pack` | grant ID, grant state, expiry, range bounds (extends SPEC-0032) |
| `auditor.grant.manage` | `tenant` | grant scope and expiry |

Grant state, expiry and scope are facts read from Identity & Access at decision time; none is a
caller claim, and no grant may be asserted in a request, a cookie, or an event.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A grant is scoped to a tenant, a date range and the packs within it, and confers **no
  repository read** — proven by an auditor principal attempting a repository read and receiving a
  coarse denial that is audited.
- [ ] AC2: The grant is read-only: every write path, including triage, policy authoring, approval and
  import, is denied for an auditor principal.
- [ ] AC3: The grant is time-boxed and expires **without an operator action**; after expiry every
  evidence read is denied.
- [ ] AC4: Granting, using, expiring and revoking each append an immutable audit record naming the
  granting admin and the auditor principal, correlated to the decision ID (ADR-0007).
- [ ] AC5: The grant is expressed in `governance/policies` and enforced by the PDP — not by a UI
  role toggle, a BFF check, or a token scope claim.
- [ ] AC6: An auditor principal cannot enumerate the existence of tenants, repositories, packs, or
  findings outside the grant; denial and not-found are indistinguishable (SPEC-0001).
- [ ] AC7: **Revocation is immediate** — a revoked grant fails the very next decision, proven without
  waiting for a cache cycle or a bundle change, because grant state is a decision-time input.
- [ ] AC8: A grant cannot be renewed by use, cannot be self-extended by the auditor, and cannot be
  widened without a new `auditor.grant.manage` decision.
- [ ] AC9: `buf lint` and `buf breaking` are green; additions are additive within v1 (ADR-0032).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | grants are tenant-scoped and non-enumerating beyond their scope |
| G2 least privilege | evidence read without repository read; read-only by construction; expiry without operator action |
| G5 auditability | grant lifecycle is itself immutable evidence |
| G6 compliance | an external auditor obtains scoped evidence without an engineer in the loop (PR-17/PR-18) |
| G9 least-privilege footprint | the grant carries scope and expiry only, never a repository permission or a role that implies one |

## Non-functional

- Grant checks add negligible latency to evidence reads; grant state lookup is on the decision path
  by design, not cached past a decision.
- A grant with a malformed, missing or tenant-mismatched scope fails closed.
- Denial and not-found errors are byte-identical for nonexistent, out-of-scope and expired resources.

## Open questions / assumptions

- **Maximum grant duration** and whether a default expiry exists are approval-time product decisions;
  this spec requires an expiry, not a particular bound.
- **Auditor authentication.** Whether an auditor authenticates through the tenant's IdP or a
  first-party credential is an Identity & Access decision (SPEC-0006, ADR-0045). If neither covers an
  external party, that is a Proposed ADR, not a spec choice.
- ~~**Retention gate.**~~ **Settled by ADR-0055 (Accepted 2026-08-14):** packs are self-contained, so
  a grant shows the same content whenever it is exercised; nothing a grant can reach ages out beneath
  it.
