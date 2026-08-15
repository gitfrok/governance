# Plan — Phase 3.1: North Star (durability, custody, multi-cluster, commercial maturity)

**Status:** **Planned (2026-08-15)** — plan accepted; **SPEC-0042…SPEC-0046 Approved** and
**ADR-0062…ADR-0065 Accepted** (2026-08-15); every epic may go RED.
**Objective:** Phase 3's recorded limits become production posture — durable control-plane stores,
residency's operator handle on a PDP-decided wire surface, agent-CA keys in custody with staged
rotation, the conformance matrix answered on real clusters, honest divergence health gates through to
the browser, and the PR-7 read-only distinction surfaced — with git never blockable, the control
plane the sole metering authority, and no inbound path opened.

## Context — where Phase 3 actually landed

Phase 3 is implementation-complete (2026-08-15): T-0030…T-0034 all Done with exit records in
`../tasks/`, every task-level acceptance criterion proven by named tests at the exit pins. The fifth
exit criterion — the whole path on a real customer-shaped cluster — is carried to T-0003's cluster
lane, recorded as carried proof, not counted as met.

The 2026-08-15 review added one carry with teeth: the envelope throttle is computed centrally,
published as desired state and acked, but **no data-plane consumer applies it** — SPEC-0041 AC5's
behaviour does not happen in a customer's cluster. **T-0035** owns that data-plane half plus the
design decision it needs (claim gate, scaler input, or both). T-0035 was opened on EP-18's books
*before* this phase was planned and is not renumbered into it; it gates T-0043, because an unapplied
throttle cannot be observed being applied.

The carried set this phase picks up (from `../backlog/` §Phase 3): the in-memory agent/residency
stores (Postgres adapters), the residency Declare wire surface, the enrolment CA's production key
custody, the real-cluster conformance proof with SPEC-0039 AC8, and the PR-7 read-only product
distinction. Closed by the review and carried nowhere: the CA trust-ordering fix (backend@e722046)
and the no-inbound fitness scan's derived tree list.

## North Star

A production-ready multi-cluster posture. A tenant's data planes run where the tenant declared, on
identity rooted in custody-held keys, and it is provable: declarations outlive control-plane
restarts, contradictions are visible with the existing vocabulary, and evidence packs assemble from
durable projections only. The operator ships as a vendor-signed, digest-pinned image; the versioned
trust bundle distributes and rotates across N data planes without re-enrolment or downtime; and the
conformance matrix answers on real GKE, EKS and AKS clusters — "not run" stops being the default.
Usage stays honest per dimension: divergence is shown with both numbers and never smoothed into a
metered figure, the applied throttle is observable end to end, deferred dimensions read "not
metered", and any read-only state names its cause. Git is never blockable in any envelope state; the
control plane remains the sole metering authority (ADR-0061); nothing opens an inbound path
(ADR-0011).

## What is already decided

Like Phase 3, the architecture predates the plan — all four decisions are Accepted:

- **ADR-0062** — Postgres adapters behind the existing module ports, swapped at the composition
  root; additive module-owned migrations; RLS on every new table; effective-dated declarations; pack
  assembly from durable projections only. No new store engine, no snapshot files, no SQLite sidecar.
- **ADR-0063** — Declare is an additive `contracts/proto/residency/v1` control-plane admin surface;
  operators declare, the PDP decides, every act is audited; the agent channel is never a declaration
  path.
- **ADR-0064** — CA keys live in platform-secrets/KMS custody behind a narrow interface holding key
  references, never material; rotation is a staged trust bundle with a dual-validate window and no
  fleet re-enrolment; the dev CA is unreachable from the production composition root.
- **ADR-0065** — the operator is a vendor-signed, digest-pinned first-party image; N data planes per
  tenant keyed by `data_plane_id`; metering aggregates per tenant; posture differences between a
  tenant's planes are defects, not tiers.

## Workstreams

| Epic | Requirement | Tasks | Specs |
|---|---|---|---|
| **EP-19** Durable control-plane stores | PR-20, PR-22 | T-0036, T-0037 | SPEC-0042 |
| **EP-20** Residency Declare & placement hardening | PR-22 | T-0038, T-0039 | SPEC-0043 |
| **EP-21** Agent-CA custody & rotation | PR-20 | T-0040 | SPEC-0044 |
| **EP-22** Multi-cluster BYO readiness | PR-20, PR-21 | T-0041, T-0042 | SPEC-0045 |
| **EP-23** Usage-view truth & PR-7 distinction | PR-23, PR-7 | T-0043, T-0044 | SPEC-0046 |

## Milestones and the dependency spine

- **M1 — Durability (EP-19):** T-0036 → T-0037.
- **M2 — Residency ∥ custody (EP-20 ∥ EP-21):** T-0038 → T-0039 ∥ T-0040.
- **M3 — Multi-cluster (EP-22):** T-0041 → T-0042 (blocked-by T-0003's cluster lane).
- **M4 — Commercial maturity (EP-23):** T-0043 (blocked-by T-0035) → T-0044.

**Why this spine.** Durability comes first because everything above it grows the registry or cites
the pack: EP-20's wire surface is pointless over a volatile store (SPEC-0043's own assumption), and
EP-22's multi-plane registry leans on the same durable liveness records — T-0036 lands the
adapter/migration pattern once and T-0037 repeats it for declarations and the pack assembly that
reads them. EP-20 and EP-21 then run in parallel because they touch different modules —
residency/audit versus the agent CA — and neither gates the other; within EP-20 the surface (T-0038)
precedes the hardening that consumes its effective-dated changes (T-0039). EP-22's harness half
(T-0041) precedes its real-cluster half (T-0042), which no amount of code can unblock — only the
lane. EP-23 waits on T-0035, because SPEC-0046 AC3 is untestable until the data plane applies the
throttle; the read-only distinction (T-0044) lands last, rendering against live states. Everything is
additive-first per ADR-0027: the one contract change is a new versioned package (`residency/v1`),
and the only other possible contract touch (trust-bundle staging) is conditional and explicitly
under its own governance PR first.

## What this phase must not do

- **No inbound paths beyond the agent channel** — every new behaviour rides the outbound-only
  connection that already exists; the no-inbound tripwire is re-asserted for the multi-plane shape.
- **No custom billing engines and no overage billing** (ADR-0008); prices, tiers and plan names stay
  out. Nothing in this phase bills.
- **No customer-run operator binaries** — the operator is a first-party signed image (ADR-0065
  decision 1), not an install value a customer supplies.
- **No features needing architectural decisions beyond the four Accepted ADRs.** A requirement that
  needs a new decision stops the line at a Proposed ADR (ADR-0001) — it does not get designed inside
  a task.
- **No GitLab-breadth chasing.** PRD §7 (non-goals) stands in full; scope here is the carried set
  and nothing adjacent to it.

## Exit criteria

- [ ] All SPEC-0042…0046 acceptance criteria green — including at least one real cluster per cloud,
      or an honestly annotated subset with named causes (the conformance matrix's own rule; never a
      silent "not run").
- [ ] Durable-store restart proofs: token spend, registry staleness and residency declarations
      survive a control-plane kill-and-restart against real Postgres, and pack assembly is proven
      unable to reach in-process stores (SPEC-0042 AC1–AC4).
- [ ] Custody off-disk proofs: the production composition root cannot construct a CA from disk or
      env, the dev CA is unreachable, and staged rotation is proven with no re-enrolment
      (SPEC-0044 AC1–AC3).
- [ ] Divergence gates shipped through webfrontend: both numbers rendered, applied throttle
      observable end to end, never-zero/never-blocked pins failing the build on regression
      (SPEC-0046).
- [ ] Full gate matrix green at the final pin bump — every repo, one commit per submodule, submodule
      pins referencing merged commits only (invariant 25).
- [ ] Runbook current: the rotation procedure with its removal precondition, and the clock-skew
      symptom cross-reference (SPEC-0044 AC4).

## Risks

- **The cluster lane bounds M3.** T-0042 is the only task whose blocker is infrastructure, and it is
  the phase's headline proof; if a lane is unavailable, the exit is an honestly annotated subset —
  the plan says so up front rather than discovering it at exit.
- **KMS provider selection is open by design.** ADR-0064 keeps it a deployment concern; the risk is
  the custody interface growing wide enough that a future general platform-secrets ADR cannot absorb
  it — decision 2 exists to prevent exactly that.
- **T-0035's mechanism decides AC3's shape.** If the chosen throttle mechanism (claim gate, scaler
  input, or both) reports too little applied-state fact, SPEC-0046 AC3 carries honestly in T-0035's
  exit record rather than being weakened here.
- **Proxy-only egress remains the standing install-blocker** outside this phase's scope (ADR-0017's
  remaining follow-up) — able to block a sale outright and unchanged by anything below.
