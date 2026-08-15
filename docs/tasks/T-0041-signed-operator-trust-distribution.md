# T-0041: Signed operator image and cross-plane release-trust-bundle distribution

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-22 (multi-cluster BYO readiness)
- **Repo(s):** backend (registry keying, release-trust distribution across planes), super-repo (operator
  image build/sign, digest pin, harness lanes) — one commit per repo
- **Spec:** docs/specs/SPEC-0045-multi-cluster-byo-readiness.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0065, 0044, 0035, 0013, 0011, 0061, 0060
- **Owner:** unassigned

## Goal

Make the operator a vendor-signed, digest-pinned first-party image and make release-trust distribution work
across N data planes per tenant (ADR-0065): the registry keys planes by `data_plane_id`, the
versioned release trust bundle distributes and rotates over the outbound-only channel that already exists,
and metering aggregates per tenant so no plane can under-report itself into a smaller envelope. The
harness half is proven here; the real clusters are T-0042's.

## Acceptance criteria (test-first)

SPEC-0045 AC1, AC2 (harness half), AC4, AC5 (AC3 and AC2's real-cluster half are T-0042's):
- [ ] AC1: the operator ships as a vendor-signed container image, digest-pinned in the signed release
      manifest — one more first-party image under the existing cosign custody, release manifest and
      verification tests (extends ADR-0044/ADR-0035; no new signing model, no new trust root); the
      install stops depending on a customer-supplied operator image.
- [ ] AC2 (harness half): the versioned release trust bundle distributes and rotates across at least two
      harness clusters without downtime — the staged dual-validate overlap applied per fleet.
- [ ] AC4: a multi-plane tenant can enrol per plane, upgrade per plane and be metered per plane, with
      envelopes computed on the tenant's aggregate — no plane under-reports itself, a silent plane's
      gap renders as a gap, and a posture-parity defect test fails on any capability difference
      between the planes of one tenant (ADR-0065 decision 4).
- [ ] AC5: the chart renders zero inbound for the multi-plane shape, and the no-inbound architecture
      fitness assertion is re-run with more than one data plane registered (SPEC-0039 AC4's tripwire,
      extended to N planes).

## Tests to write first

Per SPEC-0045 § Test plan:
- harness-first execution scripts: bring up ≥2 harness data planes for one tenant, enrol both,
  distribute and rotate the release trust bundle across them, assert no downtime during overlap (AC2).
- release gates: `check-signed-releases.sh` extended to the operator image's digest pin, and
  `check-byo-chart.sh` asserting the chart no longer carries a customer-supplied operator image
  requirement (AC1).
- posture-parity test comparing the planes of one tenant across enforced and evidenced behaviours,
  plus per-plane metering and tenant-aggregate envelope tests (AC4).
- multi-plane no-inbound fitness re-assertion (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- super-repo: `make verify` (signed-releases and byo-chart rows extended by this task), codegen-check,
  surfaces-check, policy-composition — split commits, one per submodule.

## Notes / open questions

The artifact this task distributes is the **release trust bundle** — the cosign release-signing keys
of ADR-0044, extended per fleet by ADR-0065 decision 2. It is not the **CA trust bundle** T-0040
rotates (agent identity roots, ADR-0064). Both ride the reconcile path and both stage with a
dual-validate overlap, so the mistake available here is proving one with the other's test. If the
implementation ends up sharing one staging mechanism, record that in the exit record together with the
dependency it creates on T-0040 — the plan currently sequences EP-21 and EP-22 as independent.

The number of planes a tenant may run is not capped here — ADR-0065 rejected a hard limit as a
constraint invented to avoid testing concurrency. The certificate already names tenant and data plane
(ADR-0060 decision 3); per-plane rollout-status rendering is assumed to need no vocabulary change
(SPEC-0045's assumption). Customer-built or customer-run operator images are a non-goal
(ADR-0065 decision 1).
