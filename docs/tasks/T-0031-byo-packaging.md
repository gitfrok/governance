# T-0031: Helm chart, Operator, and the per-cloud driver seam

- **Status:** Done (2026-08-15) — backend@4b26cb2, super-repo@150cc2b; SPEC-0039 AC1/AC2 proven;
  AC8's real-state proof carried to T-0003's cluster lane
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
- [x] The conformance matrix states, per row, what was verified on a real cluster and what was
      verified in a harness. A blurred row is a failed criterion.
- [x] The chart carries no secret; the enrolment token is install-time input and is not persisted.

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

## Exit record (2026-08-15)

Implemented test-first and merged: backend main at **4b26cb2** (cloud-driver seam for GKE/EKS/AKS plus
the agent-client self-registration), super-repo main at **150cc2b** (chart
`deploy/helm/gitfrok-dataplane`, the Operator seam, the conformance matrix at
`deploy/conformance/byo-dataplane.md`, and `scripts/check-byo-chart.sh` wired into `verify`).

**SPEC-0039 AC1/AC2, one line of proof each:**

- **AC1** — one `helm install` plus an enrolment token brings up a data plane that self-registers;
  the conformance matrix names each of GKE/EKS/AKS per row. What was verified on a real cluster vs a
  harness is stated per row and never blurred: **all 14 rows are harness-evidence only, every
  real-cluster column reads "not run"** — honest by construction, not a green wash.
- **AC2** — every per-cloud difference sits behind the driver seam; a provider-specific import
  outside the driver package fails the arch test the way invariant 22's does, so a new provider is a
  driver plus a matrix row, not a module change.

**The two task-specific criteria:**

- **Conformance matrix per-row honesty** — asserted above; no row blends harness and real-cluster
  evidence.
- **No secret in the chart** — asserted by a gate: the enrolment token never appears in any
  chart-rendered artifact, and the chart is install-time-input only. Anti-faking is proven two ways:
  the token is asserted absent from every rendered artifact, and the chart renders **zero inbound
  surfaces** (no Service/Ingress/NodePort/LoadBalancer), the agent opens no listener, and the
  inbound tripwire counted **0**.

**Carried — the one criterion this task named but the exit does not prove:**

- **SPEC-0039 AC8** — upgrades never destroy tenant data, and the migration path across the version
  window is proven forward and backward on real state. This task's AC list names AC8, but the merged
  work proves AC1/AC2 only; AC8's real-state migration proof is **not** among the exit evidence and
  is recorded as carried to T-0003's cluster lane with the phase's real-cluster residue — the same
  split shape T-0029's AC10 used, recorded rather than papered over.

**Cluster-bound residue.** The phase's "whole path proven end to end on a real customer-shaped
cluster" remains open and is carried to T-0003's cluster lane; the conformance-matrix rows exist and
are all marked real-cluster "not run".
