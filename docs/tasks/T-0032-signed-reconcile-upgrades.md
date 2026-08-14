# T-0032: Signed releases, reconcile rollout, rollback

- **Status:** Done (2026-08-15) — governance@dea5476, backend@85b773c, super-repo@149b3e2;
  SPEC-0039 AC3–AC7 proven; real-cluster rollout proof is the phase exit, carried to the cluster lane
- **Phase / Epic:** 3 / EP-16 (packaging and lifecycle)
- **Repo(s):** super-repo (release signing, trust bundle), backend (desired-state and rollout
  reporting) — one commit per repo
- **Spec:** docs/specs/SPEC-0039-byo-packaging-upgrades.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0013, 0011, 0044, 0017
- **Owner:** unassigned

## Goal
Ship upgrades to a cluster we cannot reach: signed release, published desired version, Operator
converges, actual version reported back, failure rolls back and says why.

## Acceptance criteria (test-first)
SPEC-0039 AC3–AC7. The load-bearing ones:
- [x] AC4: a test fails if any control-plane component dials a data-plane address. Outbound-only is
      an assertion, not a convention.
- [x] AC5: a failed upgrade rolls back and reports a reason; no silent half-applied state.
- [x] AC6: a data plane silent since a rollout began is stale, never "upgraded".

## Tests to write first
- unit: signature verification refusing unsigned and mis-signed releases without touching the
  running version.
- integration: rollout → failure → rollback against a fake cluster; staleness after a silent data
  plane.
- fitness: the no-inbound assertion above, alongside the existing dependency-direction gates.

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony.

## Notes / open questions
Version-window and pin/defer semantics (AC7) touch the commercial conversation; keep the window
configurable and its expiry visible before it bites.

## Exit record (2026-08-15)

Implemented test-first and merged across three repos, ADR-0027 order: governance main at **dea5476**
(additive `RolloutPhase` plus `ActualStateReport.rollout_phase`/`rollout_message`), backend main at
**85b773c** (`modules/rollout`: signed-release verification per ADR-0044's key model, reconcile
rollout + rollback), super-repo main at **149b3e2** (`sign-release.sh`, `check-signed-releases.sh`,
the trust bundle at `deploy/releases/trust/`, a signed `dataplane-app-0.1.0.release`, and the
operator trust-root mount).

**SPEC-0039 AC3–AC7, one line of proof each:**

- **AC3** — a release's signature is verified before anything is applied; an unsigned or mis-signed
  release is refused, audited, and leaves the running version untouched (ADR-0044).
- **AC4** — no inbound connection is ever opened to the customer's cluster; the architecture fitness
  test fails if a control-plane component dials a data-plane address — outbound-only is an assertion,
  not a convention.
- **AC5** — a failed upgrade rolls back to the previous version and reports the failure with a
  reason; no silent half-applied state.
- **AC6** — rollout is observable per data plane (desired/actual/in-progress/failed/rolled back); a
  data plane silent since a rollout began is stale, never "upgraded".
- **AC7** — a customer may pin or defer within a supported window whose expiry is visible before it
  is reached; upgrades are never silently forced on a running cluster.

**Recorded limits:**

- **The Operator binary is deliberately not shipped.** The reconcile path is proven against the
  contract and harness; a live rollout on a real cluster is the phase's exit criterion, carried to
  T-0003's cluster lane, not this task.
- **Cluster-bound residue.** The phase's "whole path proven end to end on a real customer-shaped
  cluster" remains open; the conformance-matrix rows exist and are all marked real-cluster "not run".
