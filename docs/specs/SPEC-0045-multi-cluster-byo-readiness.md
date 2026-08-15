# SPEC-0045: Multi-cluster BYO readiness

- **Status:** Approved (2026-08-15; **amended 2026-08-15 after the Phase 3.1 plan review** — the artifact this spec rotates is named the *release* trust bundle throughout, to keep it apart from SPEC-0044's CA trust bundle; **amended 2026-08-15 (T-0041)** — the release trust bundle gains its own additive field on agent/v1 `DesiredState` (`release_trust_bundle`), named and typed strictly apart from SPEC-0044's `ca_trust_bundle`)
- **Owner:** platform
- **Context(s):** Release machinery (signed operator image) · Control plane (registry, trust distribution, metering) · Data plane fleet (N planes per tenant) — ADR-0022
- **ADRs:** 0065 (decides multi-plane readiness), 0044 (signing custody — extended, not replaced), 0035 (first-party images), 0013 (Helm + Operator), 0011 (outbound-only), 0061 (metering authority — unchanged), 0060
- **Task(s):** T-0041 (AC1, AC2 harness half, AC4, AC5), T-0042 (AC3, AC2 real-cluster half — depends on T-0003's cluster lane)

## Problem / context

PR-20 and PR-21 were proven in Phase 3 against one harness-shaped data plane, and every real-cluster
column of the conformance matrix (`deploy/conformance/byo-dataplane.md`) reads "not run" — the phase's
fifth exit criterion was carried to T-0003's cluster lane, not met. Meanwhile SPEC-0038's open
questions had already noticed that nothing refuses a second data plane for one tenant, and nothing
depends on it either: a tenant that wants another region within the declared cloud, or a dedicated
burst-CI plane, had no written answer.

ADR-0065 (Accepted) writes the answer: the operator ships as a vendor-signed, digest-pinned image;
the versioned **release trust bundle** (the cosign release-signing keys of ADR-0044) distributes
and rotates across N data planes over the outbound-only
channel that already exists; the registry keys planes by `data_plane_id`; metering aggregates per
tenant; and any capability difference between the planes of one tenant is a defect, not a tier. This
spec makes that readiness executable for Phase 3.1 epic **EP-22** (PR-20/PR-21).

## In scope

- The operator as a shipped, signed first-party image, digest-pinned in the signed release manifest.
- Trust-bundle distribution and rotation across multiple data planes without downtime.
- Executing the conformance matrix on real GKE, EKS and AKS clusters.
- Multi-plane enrolment, upgrade and metering under one tenant; posture parity as a tested rule.
- Re-asserting the zero-inbound property for the multi-plane shape.

## Out of scope

- Customer-built or customer-run operator images/binaries — the operator is a first-party signed
  image (ADR-0065 decision 1) and a customer-supplied operator image stops being an install value.
- Inbound paths of any kind (Phase 3.1 non-goal); every new behaviour rides the outbound channel.
- Per-plane product tiers or capabilities — posture parity is a rule, differences are defects
  (ADR-0065 decision 4).
- Metering authority changes (ADR-0061 is not revisited) and overage billing (ADR-0008 forbids it).
- Residency migration of existing data between planes (SPEC-0040's open question, unchanged).

## Contracts touched

`contracts/proto/agent/v1` — **additive** (ADR-0027): the staged release trust bundle needs a
field the channel did not carry, so it rides the reconcile path (SPEC-0039) as desired state —
`DesiredState.release_trust_bundle` (field 4), a `ReleaseTrustBundle` carrying a monotonic
bundle revision, the trusted cosign release-signing keys (`ReleaseTrustKey`, `repeated` for the
dual-validate overlap) and the `signing_key_id` new releases sign with. It is NOT SPEC-0044's
`ca_trust_bundle`: a different artifact on a different field with a different type
(this spec's two-bundles note). The registry's `data_plane_id` keying and per-plane states are
backend state; the certificate already names tenant and data plane (ADR-0060 decision 3).

## Data owned

The release machinery owns the operator image, its signature and its digest pin. The control plane
owns the registry (per-plane liveness, staleness, rollout status) and the tenant-aggregate metering
inputs. Each data plane owns its own operational counters, which remain non-authoritative
(ADR-0061 §2).

## Acceptance criteria (each becomes a test)

- [ ] AC1: The operator ships as a vendor-signed container image, digest-pinned in the signed release
  manifest — **extends ADR-0044 and ADR-0035 with one more first-party image under the existing
  cosign custody, release manifest and verification tests; no new signing model, no new trust
  root.** The install stops depending on a customer-supplied operator image.
- [ ] AC2: The versioned **release trust bundle** distributes and rotates across at least two harness clusters
  without downtime — the staged dual-validate overlap applied per fleet — and the same procedure then
  runs on the real clusters of the conformance matrix. No new endpoint, no inbound path.
- [ ] AC3: The conformance matrix rows in `deploy/conformance/byo-dataplane.md` are executed on real
  GKE, EKS and AKS clusters — every row green or explicitly annotated with its cause. "Not run"
  stops being the honest default and becomes a named, explained exception only.
- [ ] AC4: A multi-plane tenant can enrol per plane, upgrade per plane and be metered per plane, with
  envelopes computed on the tenant's aggregate — no plane can under-report itself into a smaller
  envelope, and a silent plane's gap renders as a gap, not as zero. A posture-parity defect test
  asserts that any capability difference between the planes of one tenant fails as a defect
  (ADR-0065 decision 4).
- [ ] AC5: Zero inbound surfaces remain: the chart renders zero inbound for the multi-plane shape,
  and the architecture fitness test's no-inbound assertion is re-run with more than one data plane
  registered (SPEC-0039 AC4's tripwire, extended to N planes).

## Test plan

- Harness-first execution scripts: bring up ≥2 harness data planes for one tenant, enrol both,
  distribute and rotate the release trust bundle across them, assert no downtime during overlap (AC2).
- Release gates: `check-signed-releases.sh` extended to the operator image's digest pin, and
  `check-byo-chart.sh` asserting the chart no longer carries a customer-supplied operator image
  requirement (AC1).
- Cluster-lane execution on real GKE, EKS, AKS for the matrix rows — **explicit external dependency
  on T-0003's cluster lane**, where the phase's carried fifth exit criterion already lives; this spec
  does not conjure clusters the lane does not yet provide (AC3).
- Posture-parity test comparing planes of one tenant across the product's enforced and evidenced
  behaviours (AC4), plus per-plane metering and tenant-aggregate envelope tests.
- Multi-plane no-inbound fitness re-assertion (AC5).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G3 Supply-chain security | the operator is a signed, digest-pinned first-party image under existing custody (AC1) |
| G6 Compliance frameworks | the conformance matrix answers on real clusters, not only harnesses (AC3) |
| G8 Cost governance | envelopes bind the tenant's aggregate across planes; a plane cannot under-report itself (AC4) |
| G9 Least-privilege footprint | multi-plane readiness adds zero inbound surfaces, re-asserted by test (AC2, AC5) |

## Non-functional

- Harness lanes run in CI; real-cluster lanes run in the cluster lane's own cadence and record their
  evidence in the matrix, keeping the two provable and distinguishable.
- The number of planes a tenant may run is not capped here; ADR-0065 rejected a hard limit as a
  constraint invented to avoid testing concurrency.

## Open questions / assumptions

- Assumed: T-0003's cluster lane can provide real GKE, EKS and AKS clusters on demand; if a lane is
  unavailable, its matrix rows carry the explicit cause annotation rather than silence (AC3's rule
  applied to the spec's own dependency).
- Assumed: per-plane rollout status rendering (SPEC-0039 AC7) needs no vocabulary change to render
  more than one plane — it lists planes today.
- **Two bundles, one channel.** This spec's release trust bundle (cosign release-signing keys,
  ADR-0044/ADR-0065) and SPEC-0044's CA trust bundle (agent identity roots, ADR-0064) both ride the
  reconcile path and both stage with a dual-validate overlap, but they are different artifacts with
  different owners, rotated for different reasons. Neither spec's ACs may be proven by the other's
  test. If the implementation shares one staging mechanism between them, that reuse is stated in
  T-0041's exit record together with the dependency it creates on T-0040 — silently sharing it is the
  failure mode this note exists to prevent.
