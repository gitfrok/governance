# SPEC-0039: BYO packaging, per-cloud drivers, and signed reconcile-based upgrades

- **Status:** Draft
- **Owner:** platform
- **Context(s):** Packaging and lifecycle of the data plane — ADR-0013, ADR-0010
- **ADRs:** 0013 (Helm + Operator), 0010 (GKE/EKS/AKS portability), 0011, 0017, 0044 (image trust), 0060
- **Task(s):** T-0031, T-0032

## Problem / context

PR-20 needs the data plane installable into a customer's cluster; PR-21 needs upgrades shipped as
signed releases with reconcile-based rollout and rollback, without inbound access. ADR-0013 fixes
Helm plus an Operator; ADR-0010 fixes GKE/EKS/AKS as the portability target and a driver seam for
what differs between them.

The hard part is not templating. It is that we operate software we cannot reach: every upgrade is a
desired state the customer's cluster converges to on its own, and every failure has to be visible and
reversible from our side without a shell in their cluster.

## In scope

- The Helm chart and Operator CRD that install and own a data plane.
- The per-cloud driver seam: storage classes, ingress, identity and load-balancer differences across
  GKE, EKS and AKS, and a conformance matrix that says what is verified where.
- Release signing and verification, reusing the ADR-0044 trust-bundle mechanism.
- Reconcile-based rollout, health gating, and rollback.

## Out of scope

- Enrolment and identity (SPEC-0038).
- Metering and envelopes (SPEC-0041).
- Air-gapped installation (PRD non-goal 1).
- Any inbound path into the customer's cluster, in any form, for any reason.

## Contracts touched

`contracts/proto/agent/v1` — additive desired-state and rollout-status messages within the existing
envelopes.

## Data owned

The control plane owns the desired version per data plane and the rollout history. The Operator owns
the CR's status in the customer's cluster. Neither invents the other's state: the control plane never
guesses a version it has not been told is running.

## Acceptance criteria (each becomes a test)

- [ ] AC1: One `helm install` plus an enrolment token brings up a data plane that self-registers
  (SPEC-0038), on each of GKE, EKS and AKS. What is verified on a real cluster versus a conformance
  harness is stated per row, never blurred.
- [ ] AC2: Everything that differs per cloud sits behind the driver seam. A new provider is a driver
  plus a matrix row, not a change in module code — asserted by a boundary test, the way invariant 22
  is.
- [ ] AC3: A release is signed and its signature verified before anything is applied. An unsigned or
  mis-signed release is refused, audited, and leaves the running version untouched (ADR-0044).
- [ ] AC4: Upgrades are reconcile-based: the control plane publishes a desired version, the Operator
  converges, and the data plane's actual version is reported back. No inbound connection is ever
  opened to the customer's cluster — asserted by a test that fails if a control-plane component
  dials a data-plane address.
- [ ] AC5: A failed upgrade rolls back to the previous version and reports the failure with a reason.
  A data plane never sits in a half-applied state without saying so.
- [ ] AC6: Rollout is observable per data plane: desired version, actual version, in-progress,
  failed, rolled back. A data plane that has not reported since a rollout began is stale, never
  "upgraded".
- [ ] AC7: A customer may pin or defer a version within a supported window, and the window's
  expiry is visible before it is reached. Upgrades are not silently forced on a running cluster.
- [ ] AC8: An upgrade never destroys tenant data, and the migration path across the version window is
  proven forward and backward on real state — the same standard the dev-provision migrations meet.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G5 boundaries | per-cloud differences live behind the driver seam, asserted by test (AC2) |
| G6 evidence | signature verification and rollout outcomes are auditable facts (AC3, AC6) |
| G7 residency | the install declares cloud and region, which SPEC-0040 then holds us to |
| G9 operability | reconcile, rollback, and honest staleness rather than assumed success (AC4–AC6) |

## Non-functional

- The chart carries no secret and no credential; the enrolment token is supplied at install time and
  is not persisted by the chart (SPEC-0038 AC2).
- Supported-version window and reconcile interval are per-environment configuration.

## Open questions / assumptions

- Which cloud gets a real cluster in CI versus a conformance harness is a cost decision, and AC1
  demands it be stated rather than implied.
- Assumed: the Operator runs in the customer's cluster with namespace-scoped permissions; a
  cluster-admin requirement would be a decision, not a detail.
