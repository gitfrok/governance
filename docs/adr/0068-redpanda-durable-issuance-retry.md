# ADR-0068: Redpanda-backed durable issuance retry

- **Status:** Proposed
- **Date:** 2026-08-15
- **Deciders:** platform (drafted as a Phase 3.2 candidate at the Wave 1 close-out of Phase 3.1)
- **Supersedes / superseded by:** — (if Accepted, would supersede the interim AC6 posture SPEC-0042
  fixed on 2026-08-15; no ADR is superseded — AC6 lives in a spec, and this ADR's acceptance would
  carry that spec's amendment)
- **Related:** ADR-0060 (enrolment token + control-plane-issued certificates; the one-token-one-identity
  rule any retry must keep), ADR-0066 (issuance is a remote call to a quorum-serialized custody
  service — the outage this absorbs), ADR-0062 (the durable stores this queue sits beside), ADR-0023
  (Redpanda is already in the stack), SPEC-0042 (AC6's interim decision), T-0036 (implemented and
  proved the interim behaviour)

## Context

T-0036 made token spend durable (SPEC-0042 AC1) and T-0040's custody half makes issuance a remote
call to a quorum-serialized service (ADR-0066). Together they created the window SPEC-0042 AC6
names: between `ClaimToken` and `Issue`, a custody or seal outage turns an availability event into
a dead customer credential. AC6 settled this on 2026-08-15 by **user decision**: release the claim
on issuance failure, keep the claim's recorded `data_plane_id`, and bind any retry to that same
identity so one token never mints two data planes (ADR-0060). T-0036 proved that behaviour against
real Postgres (`TestEnrolIssuanceFailureReleasesClaimKeepingIdentity`,
`TestStore_ReleaseClaimKeepsRecordedDataPlane`, `TestEnrolReleasedClaimStillHonoursRevocation`).

Release-the-claim is correct and minimal, but it is an interim posture, and AC6's own wording
anticipated a durable alternative ("…or keep the spend with a named operator recovery"). Its costs:

- **Enrolment interrupts on custody availability.** A sealed or degraded custody quorum makes every
  enrolment fail synchronously; the customer's agent retries from the outside, and a prolonged
  outage turns enrolment into an operator-tended procedure exactly when operators are busy with the
  custody incident itself.
- **Recovery is re-presentation, not resumption.** The released claim puts the token back in a
  spendable state, but nothing *remembers the attempt* — the retry is whatever the agent happens to
  do next, with no backoff, no ordering, and no audit-visible work item distinguishing "issuance
  pending since the outage" from "no enrolment attempted".
- **The window grows with rotation.** ADR-0064's staged rotation re-issues certificates through the
  same custody seam; rotation across a custody outage has the same shape at fleet scale.

Redpanda is already in the technology stack (ADR-0023) and the control-plane topology already
assumes event-driven subscribers (ADR-0059's runner-persists/subscriber-ingests shape is prior art
for exactly this "durable work, retried consumer" pattern).

## Decision

**Proposed: certificate issuance gains a durable retry queue on Redpanda, so a custody outage never
interrupts enrolment — the claim stays held, the issuance attempt becomes a durable work item, and
a control-plane worker retries with backoff until issuance succeeds or the token expires.**

Stated as a proposal, with the shape an acceptance would fix:

1. **The claim is not released on issuance failure.** `ClaimToken` records the spend and the
   `data_plane_id` exactly as today; a failed `Issue` publishes an issuance-retry item (token id,
   recorded `data_plane_id`, attempt count, next-attempt bound) instead of unwinding the claim.
2. **Retry is a control-plane worker, not the agent.** A consumer of the issuance-retry topic calls
   the same `CertificateIssuer` seam (ADR-0066 decision 1) with backoff; success completes the
   enrolment the claim began, and the agent's next connection picks up its issued certificate. The
   agent protocol (ADR-0017/0060) does not change.
3. **ADR-0060's rule binds the queue.** Every retry item carries the claim's recorded
   `data_plane_id`; no path through the queue can mint a second identity for the token. Expiry or a
   bounded attempt ceiling is the only terminal failure, and it is an audited operator-visible
   event, never a silent drop.
4. **Revocation still wins.** A revocation issued while an item is queued must refuse issuance when
   the worker reaches it — the queue never outruns the revocation ledger (SPEC-0042 AC1's durable
   refusal).
5. **Custody outage stays an availability event for rotation.** ADR-0066 decision 6's contract is
   unchanged: certificates already issued remain valid until expiry. The queue absorbs *new*
   issuance; it does not promise rotation through an indefinite outage.

## Consequences

**Positive:**

- Enrolment survives custody and seal outages up to the token's expiry without operator action or
  agent-side retry correctness; the outage degrades to "issuance delayed", visible as queued work.
- The interim release-the-claim posture is superseded rather than quietly outgrown: acceptance of
  this ADR carries SPEC-0042's amendment and a migration of T-0036's behaviour, both recorded.
- The attempt record is audit-visible durable state (ADR-0007), closing AC6's "nothing remembers the
  attempt" gap.

**Negative / costs:**

- Enrolment gains a hard dependency on Redpanda availability — trading a custody outage for
  (custody ∨ broker) availability on the enrolment path. The queue must degrade explicitly (fail
  closed, claim held, operator-visible) when the broker itself is down, not silently fall back to
  release-the-claim.
- Distributed exactly-once is out of reach; the worker must be idempotent per `(token id,
  data_plane_id)` — a double-issued certificate for the same identity must be detectable and
  reconciled, not merely unlikely.
- New operational surface: topic ownership, retention bound for retry items, and the dead-letter
  shape for the bounded-attempt ceiling — all runbook obligations beside SPEC-0044 AC4's custody
  procedures.

**Follow-ups:**

- **This ADR gates nothing in Phase 3.1.** T-0036's release-the-claim behaviour remains the shipped
  and proven posture; nothing in EP-19…EP-23 waits on or implements this proposal. It is a Phase 3.2
  candidate awaiting a decision.
- If Accepted: amend SPEC-0042 AC6, re-prove the AC6 tests against the queued path, and revisit
  ADR-0064's rotation path for the same queue. If rejected: the interim posture stands and this ADR
  is marked Deprecated with the rejection reason.
- The general platform-secrets track (ADR-0057 decision 5, ADR-0066 decision 3) is untouched: this
  proposal changes *how issuance retries*, not *who holds the key*.

## Alternatives considered

- **Keep the interim posture (release the claim, agent re-presents)** — viable and proven; rejected
  *provisionally* only because recovery is un-remembered and enrolment interrupts synchronously on
  custody availability. If Redpanda-dependency cost outweighs those, this alternative wins and this
  ADR should be Deprecated.
- **Keep the spend with named operator recovery (AC6's other option)** — makes every custody outage
  a manual operator procedure to unstick a dead credential; the opposite of the goal here, and the
  operator is already busy with the custody incident.
- **In-process retry with backoff (no broker)** — a control-plane restart during the outage loses
  exactly the attempts that matter, re-creating SPEC-0042's original "state is a property of a
  process" defect at the issuance layer.
- **Postgres-backed retry table instead of Redpanda** — the closest alternative: durable without a
  new dependency on the enrolment path, at the cost of polling rather than event-driven wake-up. The
  decision between the two belongs to this ADR's acceptance review; Redpanda is proposed because the
  stack already runs it and the pattern already exists (ADR-0059).
