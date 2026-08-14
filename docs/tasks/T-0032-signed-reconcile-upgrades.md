# T-0032: Signed releases, reconcile rollout, rollback

- **Status:** Todo
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
- [ ] AC4: a test fails if any control-plane component dials a data-plane address. Outbound-only is
      an assertion, not a convention.
- [ ] AC5: a failed upgrade rolls back and reports a reason; no silent half-applied state.
- [ ] AC6: a data plane silent since a rollout began is stale, never "upgraded".

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
