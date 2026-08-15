# T-0042: Real-cluster conformance proof — GKE, EKS, AKS

- **Status:** Todo — **blocked-by T-0003's cluster lane availability** (external dependency: this
  task executes on real clusters only the lane can provide; see Notes)
- **Phase / Epic:** 3.1 / EP-22 (multi-cluster BYO readiness)
- **Repo(s):** super-repo (conformance-matrix execution and evidence recording under
  `deploy/conformance/`)
- **Spec:** docs/specs/SPEC-0045-multi-cluster-byo-readiness.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0065, 0044, 0035, 0013, 0011
- **Owner:** unassigned

## Goal

Execute the conformance matrix (`deploy/conformance/byo-dataplane.md`) on real GKE, EKS and AKS
clusters so "not run" stops being the honest default and becomes a named, explained exception only
(SPEC-0045 AC3). This is where Phase 3's carried fifth exit criterion — the whole install →
self-register → upgrade → meter path on a real customer-shaped cluster — and SPEC-0039 AC8's
forward/backward migration proof on real state are actually proven.

## Acceptance criteria (test-first)

- [ ] SPEC-0045 AC3: the conformance-matrix rows are executed on real GKE, EKS and AKS clusters —
      every row green or explicitly annotated with its cause; no row left silently "not run".
- [ ] SPEC-0045 AC2 (real-cluster half): the release-trust-bundle distribution/rotation procedure proven on
      harness clusters in T-0041 then runs on the real clusters of the matrix, without downtime
      during the overlap.
- [ ] The carried phase-3 exit criterion: the whole path — install from the chart plus an enrolment
      token, self-register over the outbound-only connection, signed reconcile upgrade with rollback
      on failure, residency enforcement, metering against fair-use envelopes — proven once end to end
      on a real customer-shaped cluster, not a harness.
- [ ] SPEC-0039 AC8 (carried from T-0031): upgrades never destroy tenant data, with the migration
      path across the version window proven forward and backward on real state.

## Tests to write first

This task's tests are the matrix rows themselves; per SPEC-0045 § Test plan (cluster-lane execution):
- cluster-lane execution on real GKE, EKS and AKS for the matrix rows, recording per-row evidence in
  the matrix — harness-lane and real-lane evidence stay provable and distinguishable.
- the rotation procedure re-run per cloud as AC2's real-cluster half.
- the forward/backward migration proof on real state (SPEC-0039 AC8).
- the matrix's own honesty rule stays in force: a blurred row is a failed row (T-0031's criterion).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (per repo):
- super-repo: `make verify` (dep direction, version floors, trust bundle, signed releases, chart),
  codegen-check, surfaces-check, policy-composition; the matrix update and lane scripts land as
  super-repo commits.

## Notes / open questions

**External dependency:** T-0003's cluster lane — the standing owner of every infrastructure-bound
demonstration since Phase 1 — must provide real GKE, EKS and AKS clusters on demand; this task does
not conjure clusters the lane does not provide (SPEC-0045's stated assumption). If a lane is
unavailable, its rows carry the explicit cause annotation rather than silence — AC3's rule applied to
the task's own dependency. Sequenced behind T-0041 (M3): the harness half must exist before the real
half runs. The plan's exit bar is at least one real cluster per cloud, or an honestly annotated
subset — never a silent one.
