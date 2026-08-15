# ADR-0063: Residency Declare is a control-plane admin gRPC surface — the agent channel never declares

- **Status:** Accepted (2026-08-15)
- **Deciders:** product/architecture (proposed by AGDD Phase 3.1 planning)
- **Supersedes / superseded by:** —
- **Related:** SPEC-0040 (PR-22), ADR-0006 (PDP decides, surfaces ask), ADR-0009 (control/data
  plane split), ADR-0011, ADR-0062 (durable declaration store), T-0033 (carried item this closes),
  policy bundle 0.9.0

## Context

PR-22 makes a tenant's residency declaration control-plane state, and Phase 3 implemented exactly
that: `residency.declaration.set` exists as an owner-only, tenant-scoped PDP action in policy
bundle 0.9.0, the PlacementGate enforces the declaration at enrolment, and the evidence pack
cites it. What does not exist is any way to invoke the action from outside the process — T-0033's
exit record carries it verbatim: *Declare has no wire/RPC surface in Phase 3; the declaration is
set by in-process composition only.*

So today an operator who needs to declare or change a tenant's pinned cloud/region has no surface
to do it with, while the enforcement, the audit vocabulary and the pack section that consume the
declaration are all live. The decision is made; the handle is missing.

## Decision

**Declare is a control-plane admin gRPC surface, added additively under `contracts/` as a
`residency/v1` service package. Operators declare and replace; the PDP decides; every act is
audited. The agent channel is never a declaration path.**

1. **Placement: a new `contracts/proto/residency/v1` with its own admin service.** This is the
   house pattern — every module-owned domain gets its own versioned package with a named service
   (`agent/v1`'s `AgentGateway`, `usage/v1`'s `UsageService`, `audit/v1`'s `EvidenceService`), and
   the residency module owns this data. It is not added to `agent/v1`, because the agent channel is
   the wrong authority for this act (see the rejection below); and not to `audit/v1`, because audit
   owns the evidence pack, not tenant control state — wedging control state into the evidence
   surface would blur which module can write it.
2. **Operators declare and replace the target cloud/region per tenant.** A replace appends a new
   effective-dated declaration and retains the history (ADR-0062 decision 6); the surface changes
   what is in force, never what was in force before it.
3. **The PDP action decides.** The surface is a PEP: it asks `residency.declaration.set`, already
   owner-only in bundle 0.9.0, and refuses coarsely when refused. The surface authorizes nothing
   itself, and no new role or bypass is created beside the existing owner grant.
4. **Every declaration, replacement and refusal appends an immutable audit record** naming the
   tenant, the actor, the previous and new pinning, and the effective time — the same one-record-
   per-act discipline SPEC-0038 AC7 applies to enrolment.
5. **The agent channel only ever reports witnessed placement facts.** The wire vocabulary already
   encodes the split — `RESIDENCY_FACT_KIND_PINNING` is a control-plane act; `PLACEMENT`,
   `PLACEMENT_REFUSED` and `PLACEMENT_CONTRADICTION` are control-plane observations of data
   planes. Declare adds nothing to the agent channel: no message, no field, no path.
6. **Contradictions surface through the existing vocabulary.** A declared-vs-observed contradiction
   raises the violation state and appears in the pack's residency section as
   `PLACEMENT_CONTRADICTION` within the configured detection window (SPEC-0040 AC3); Declare
   introduces no parallel error channel.

**Rejected: Declare over the agent channel.** One message on the stream the agent already holds,
and no new surface to build — but it inverts authority: the managed data plane would tell the
control plane where it is allowed to run. SPEC-0040 AC1 is the rule this breaks — a data plane
reporting a pin is a redefinition of control state by the party being controlled, which is
precisely what AC1 exists to forbid.

**Rejected: per-plane self-declaration.** The customer-attestation version of the same inversion —
self-attested placement flowing into control state. PR-22 excludes it by construction: a
customer's statement about their own cluster reaches the attested appendix only, never a control
section (SPEC-0040 AC7).

## Consequences

- Closes T-0033's carried item: the PDP action gains the wire surface that invokes it.
- An additive-only contract change under the v1 additive rule; `buf breaking` gates it like every
  other addition.
- No change to PlacementGate enforcement semantics — the enrolment-time coarse refusal that does
  not spend the token stands exactly as shipped.
- Changing what is declared does not move what already sits outside it: residency migration of
  existing data remains undesigned and out of scope (SPEC-0040), and the pack's change rendering
  (AC6) is what makes that honest rather than hidden.
