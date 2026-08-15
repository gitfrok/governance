# T-0041: Signed operator image and cross-plane release-trust-bundle distribution

- **Status:** Done
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
- [x] AC1: the operator ships as a vendor-signed container image, digest-pinned in the signed release
      manifest — one more first-party image under the existing cosign custody, release manifest and
      verification tests (extends ADR-0044/ADR-0035; no new signing model, no new trust root); the
      install stops depending on a customer-supplied operator image.
- [x] AC2 (harness half): the versioned release trust bundle distributes and rotates across at least two
      harness clusters without downtime — the staged dual-validate overlap applied per fleet.
- [x] AC4: a multi-plane tenant can enrol per plane, upgrade per plane and be metered per plane, with
      envelopes computed on the tenant's aggregate — no plane under-reports itself, a silent plane's
      gap renders as a gap, and a posture-parity defect test fails on any capability difference
      between the planes of one tenant (ADR-0065 decision 4).
- [x] AC5: the chart renders zero inbound for the multi-plane shape, and the no-inbound architecture
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

## Exit record (2026-08-16)

Closed in three landings over the governance-first contract already on governance main: governance
**b5128b0** (the additive agent/v1 `DesiredState.release_trust_bundle` field, named and typed apart
from `ca_trust_bundle`; `check-contracts.sh` check 8 reworked); backend **762d5f0** (operator-app,
releasebundle, gateway delivery + applied registry, migration 0002, AC2/AC4/AC5 tests, gen) and
backend **a669cef** (the interrupted composition wiring: `cmd/controlplane-app` consumes the seams —
config loading with the custody fail-fast posture, bundle construction, both attaches, the staging-dir
actuation loop); super-repo **febf0f7** (AC1: the signed operator release manifest, the chart's vendor
digest-pin default, and the two release gates extended). The super-repo pin bump naming these SHAs is
the follow-on commit. All backend proofs ran through the full gate sequence — gofmt clean, `go vet`,
`go build`, `go test ./internal/arch/... -v`, and `go test -race -count=1 ./...` against the
real-Postgres harness at `127.0.0.1:15432` with **zero failures and zero durability skips**.

**AC1 — vendor-signed, digest-pinned first-party operator; no customer-supplied image:**
`deploy/releases/operator-app-0.1.0.release` verifies under `check-signed-releases.sh` (bundle
integrity + ECDSA over the canonical identity `oci_ref@digest` — the existing custody, manifest and
verification tests of ADR-0044/ADR-0035, extended, not replaced); its digest pin is reproducible from
backend@a669cef (sha256 of the linux/amd64 operator-app binary built with Dockerfile.operator's exact
flags; the OCI image digest the release pipeline publishes is recorded there). The chart defaults
`operator.image` to the vendor pin and renders `repository@digest` — `operator.image.repository/tag`
are no longer required install values. Gates: `check-signed-releases.sh` part 3 (chart pin ⇔ signed
manifest drift) and `check-byo-chart.sh` §7b (no customer-supplied image requirement) + the
operator-enabled rendered shape with zero image values — the rendered half honestly NOT RUN on this
lane (helm absent; the gate says so on its own output line). Backend half at 762d5f0:
`TestStartupRefusesWithoutPinnedTrustBundle`, `TestVerifyBeforeApplyAndDigestPin`,
`TestMisSignedReleaseRefusedBeforeApply`, `TestUnsignedManifestRefused`, `TestIdempotentConvergence`,
`TestReleaseManifestRoundTrip`, `TestReleaseLookupRefusesPathShapedVersions` (cmd/operator-app); the
operator opens no listener — `Dockerfile.operator` from scratch, outbound-only shape holds. Signing
posture for the window: a staged throwaway key generated OUTSIDE the tree (`sign-release.sh` custody
posture, mirrored), its public half committed as `release-signing-2026-08-gen2.pub` with fingerprint
recorded; the private half never entered any repo.

**AC2 (harness half) — distribution + rotation across two harness planes without downtime:**
`TestAC2_ReleaseTrustBundleDistributedAcrossTwoPlanesWithoutDowntime` runs the whole rotation over the
wire: two planes of one tenant with DISTINCT data_plane_ids, gen1 bootstrap → gen2 stage (overlap:
both planes verify gen1 AND gen2 signatures at every instant) → gen1 removal (convergence; applied
registry keyed per data_plane_id at every step), and every delivery carrying the release bundle
provably carries NO CA bundle — one test never proves the other artifact. Window mechanics:
`TestStagedDualValidateWindowIsNoDowntime`, `TestRemovalPreconditionsKeepOldKeyTrusted`,
`TestPrivateMaterialRefused`, `TestMidWindowRestartRepublishesSameRevision`,
`TestEmptyBundleProjectsNothing`, `TestDuplicateKeyIDRefused` + the compose/snapshot/dir suites
(restart-proof epoch, corrupt snapshot refused, staging-dir actuation refuses private material before
any state change). Durability keyed by data_plane_id (migration 0002, RLS forced):
`TestReleaseTrustApplied_DurableAcrossRestart`, `TestReleaseTrustApplied_ForwardOnly`,
`TestReleaseTrustApplied_TwoPlanesKeyedSeparately`, `TestReleaseTrustApplied_RLSIsolation`,
`TestReleaseTrustApplied_RLSForcedInCatalog`, `TestReleaseTrustMigrationIsRLSIsolated`,
`TestReleaseTrustDownMigrationUndoesUp`. Composition posture (a669cef):
`TestLoadReleaseTrustConfigUnsetIsHonestAbsence`, `TestLoadReleaseTrustConfigSeedIsOneArtifact`,
`TestLoadReleaseTrustConfigRefusesMalformedInterval`, `TestLoadReleaseTrustConfigCarriesThePosture`.
Honest NOT RUN: AC2's real-cluster half — the same procedure on the conformance matrix's real
clusters — is T-0042's, and the tree-level gen2 removal step waits for fleet convergence (the README
records the window's rule).

**AC4 — per-plane enrol/upgrade/meter under a tenant-aggregate envelope:**
`TestAC4_EnvelopeComputedOnTenantAggregate`, `TestAC4_PlaneCannotUnderReportIntoSmallerEnvelope` (a
plane's low self-report becomes a divergence finding with both numbers, never a smaller counter),
`TestAC4_SilentPlaneGapRendersAsGapNotZero` (metering); posture parity is executable:
`TestPostureParityCapabilityDifferenceIsADefect`, `TestPostureParityEqualCapabilitiesPass`,
`TestPostureParityRevokedPlaneIsOutOfFleet` (`domain.PostureParityDefect`, `Service.PostureParity`,
ADR-0065 decision 4); registry keying `TestReleaseTrustApplied_TwoPlanesKeyedSeparately` and the AC2
test's distinct-`data_plane_id` enrolment assertion.

**AC5 — zero inbound, re-asserted for N planes:** `TestAC5_MultiPlaneNoInboundTripwire` (two planes
enrol, hold their channels, read CONNECTED side by side; the control plane opens no connection toward
either cluster stand-in) plus `internal/arch` fitness (zero-inbound assertion intact over the new
seams) and `check-byo-chart.sh`'s static no-inbound assertions over the multi-plane chart shape
(rendered half honestly NOT RUN — helm absent).

**Two bundles, one channel (SPEC-0045's note):** the implementations share NO staging mechanism — the
CA bundle stages through custody/OpenBao and the custody snapshot (SPEC-0044), the release bundle
through the releasebundle file snapshot and its staging directory (this task) — so this exit record
records no dependency on T-0040 beyond co-riding the outbound reconcile channel, which both specs
name by design; the per-delivery assertion in the AC2 test (release delivery carries no CA bundle and
vice versa) keeps the artifacts provably apart. EP-21 and EP-22 remain sequenced as independent.

Honest carries: AC3 and AC2's real-cluster half → T-0042 (blocked by T-0003's cluster lane); the
operator image's registry publish and the OCI image digest at publish time belong to the release
pipeline (the manifest's digest is the reproducible content pin named above); helm-rendered assertions
run only on lanes with helm.

Gates: backend gofmt/vet/build + `internal/arch` + full `-race` suite green (zero skips);
super-repo `make lint-shell`, `portability-check`, `check-signed-releases.sh`, `check-byo-chart.sh`
green; both gates negative-tested to fire on drift.
