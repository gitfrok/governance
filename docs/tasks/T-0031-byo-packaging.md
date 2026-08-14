# T-0031: Helm chart, Operator, and the per-cloud driver seam

- **Status:** Todo
- **Phase / Epic:** 3 / EP-16 (packaging and lifecycle)
- **Repo(s):** super-repo (chart, Operator, conformance harness), backend (driver seam) — one commit
  per repo
- **Spec:** docs/specs/SPEC-0039-byo-packaging-upgrades.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0013, 0010, 0009, 0060
- **Owner:** unassigned

## Goal
One `helm install` plus an enrolment token brings up a data plane that self-registers, on GKE, EKS
and AKS, with everything cloud-specific behind a driver seam.

## Acceptance criteria (test-first)
SPEC-0039 AC1, AC2, AC8, plus:
- [ ] The conformance matrix states, per row, what was verified on a real cluster and what was
      verified in a harness. A blurred row is a failed criterion.
- [ ] The chart carries no secret; the enrolment token is install-time input and is not persisted.

## Tests to write first
- boundary: a provider-specific import outside the driver package fails the arch test, the way
  invariant 22's does.
- integration: install → self-register → serve, per driver, against whatever cluster or harness the
  matrix names.
- unit: driver selection and the refusal when a required per-cloud setting is absent — no silent
  default that half-works.

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony.

## Notes / open questions
Which cloud gets a real cluster in CI is a cost decision, and SPEC-0039 AC1 forces it to be stated.
Namespace-scoped Operator permissions are assumed; needing cluster-admin would be a decision, not a
detail.
