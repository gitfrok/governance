# T-0021: Container images for both planes

- **Status:** Todo — **unblocked 2026-08-08: AC0 is met, ADR-0035 Accepted.** AC1–AC6 are ready to start.
- **Phase / Epic:** 1 / EP-10
- **Repo(s):** governance (ADR), backend (`Dockerfile`, both `cmd/` targets), bff (`Dockerfile`),
  webfrontend (`Dockerfile`, SSR — added by ADR-0035 decision 9), super-repo (`deploy/dev/`,
  `versions.env`, CI) — ADR-0027 order, one commit per repo (invariant 23)
- **Spec:** chore — acceptance criteria below. **AC0 is a Proposed ADR**, not a chore step.
- **ADRs:** 0009, 0013, 0023, 0024, 0025, 0034, **0035** (AC0's output)
- **Owner:** unassigned

## Goal
A deployable image per plane, so a policy-checked request can run end-to-end in a cluster.

Nothing in the four repos builds a container image today: there is no `Dockerfile`, `Containerfile`,
`.ko.yaml` or goreleaser config anywhere, and no `docker build` / `buildx` / `ko` / `kaniko` step in
any CI workflow. `deploy/dev/` deploys the five infrastructure services and a busybox fixture — no
plane. So the system has never run as a deployed artifact, only as `go test` and as one composed
process under `scripts/check-policy-composition.sh`.

## Why this is filed as its own task
Discovered while closing out T-0003 (2026-08-08): the policy bundle that task publishes as a
ConfigMap has **no consumer**, because there is no pod to mount it into. That is not a T-0003 defect
— T-0003's acceptance criteria are about infrastructure and TLS — and it is not a gap any existing
task owns. Filing it here rather than widening T-0003 keeps the missing-image problem visible instead
of buried in a task that is already blocked on host limits.

## Acceptance criteria (test-first)
- [x] **AC0 — a Proposed ADR for the image build surface, reviewed before any Dockerfile is written.**
      **Met: ADR-0035, Accepted 2026-08-08.** It carries a correction note — the version first merged
      claimed invariant 9 compelled key-based cosign signing, which it does not; that choice is the
      ADR's own, argued from ADR-0011. Read the note before citing decision 4.
      Its premise held — no Accepted ADR covered image *production*: ADR-0013 chose Helm + Operator and
      *assumes* images exist, and ADR-0034 governs third-party dev-env pin form. Drafting it found that
      **two parts were already decided and simply ungrounded**: invariant 9 requires the agent to apply
      only cosign-verified signed releases, and `contracts/proto/agent/v1`'s `SignedRelease` carries a
      digest the agent MUST verify — additive-only under invariant 10, so not revocable. *That* something
      is signed and digest-referenced is settled. **How it is signed was not** — key-based vs keyless is
      ADR-0035's own call (decision 4), and an earlier version of this AC wrongly said otherwise. What
      the ADR decides: base image, build tool, registry, SBOM handling, runtime posture, signing
      mechanism, and building the contract's guarantees in now rather than retrofitting them.
- [ ] AC1: one image per plane binary (invariant 19) — `cmd/dataplane-app` and
      `cmd/controlplane-app` — built from `backend/`, respecting ADR-0023's Go 1.26 floor.
- [ ] AC2: an image for `bff/`.
- [ ] AC2a: an image for `webfrontend/`'s SSR server. **Added by ADR-0035 decision 9** — this AC list
      originally named only the two planes and the BFF, but the SSR front door is equally undeployable,
      so four images are in scope, not three. It is also the one image that cannot use the Go base
      (ADR-0035 decision 3).
- [ ] AC3: the runtime posture the ADR settles is **asserted, not assumed** — a test reads the built
      image and fails on a violation (runs as non-root, read-only root filesystem, no shell).
      `deploy/dev/hello.yaml` already models this posture for the fixture; the real planes should not
      be laxer than the busybox that tests them. On a `scratch` base (ADR-0035 decision 2) the
      no-shell half is free, but it is still asserted — an image is only as posture-correct as its
      last Dockerfile edit.
- [ ] AC4: the data plane **starts and stays up** in the dev cluster with the
      `gitfrok-policy-bundle` ConfigMap mounted at `/etc/gitfrok/policy` and
      `GITFROK_POLICY_BUNDLE_DIR` set to it — and **exits non-zero without it**. Both directions are
      the test: the fail-fast is a deliberate behaviour (ADR-0006, invariant 2) and a regression that
      made it start anyway would be silent. `deploy/dev/README.md` ("Policy bundle") documents the
      mount contract this consumes; T-0003 verified the bundle loads from that mount by evaluating
      the real policy to `allow: true`, so what is untested is the plane, not the bundle.
- [ ] AC5: `deploy/dev/` gains dataplane and controlplane manifests, with their references recorded in
      `versions.env` so `check-dev-images.sh` covers them. First-party images resolve **by digest**
      (ADR-0035 decision 4), which that script already handles — it has a
      `*@sha256:*) ;; # digest-pinned: exact by construction` arm and probes resolution identically for
      a digest or a tag. So this is registering new manifests in its expected-image list, nothing more.
- [ ] AC6: CI builds the images on PR in the repo that owns each one, and `ci-gates.md` is updated —
      it currently names no image-build gate for any repo.

## Tests to write first
- integration: data plane comes up in-cluster with the bundle mounted; and exits non-zero without it
- integration: `make dev-smoke` reaches a policy-checked request end-to-end over TLS (the Phase-1
  deployment milestone — see the resolved note below)
- fitness: built images satisfy the AC3 posture; `check-dev-images.sh` covers the new tags
- boundary: no change expected, but the gates must stay green — an image build is a new way for a
  repo to reach another repo's source, and invariant 22 does not stop caring at the Dockerfile

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions

**1. Phase-0 exit criterion — resolved 2026-08-09.** Phase 0 is complete on its delivered
foundation scope: Minikube/TLS, tenancy, policy and audit seams, the storage decision, and enforced
CI gates. The end-to-end policy-checked request is a Phase-1 deployment milestone because it needs
the images built by this task. This preserves the roadmap rule that a phase exits without relying on
later-phase work.

**2. Scope check against the PRD.** Confirm against `../product/PRD.md` §7 non-goals before building.
Registry hardening is listed as *Later / not scheduled* in the roadmap — publishing our own images is
not the same thing as hardening a registry product, but the line is close enough to check rather than
assume.

**3. The controlplane image may have no consumer yet either.** AC1 builds it because invariant 19
says one binary per plane; whether `deploy/dev/` should run it in Phase 1, or whether it waits for
Phase 3's BYO CP/DP split (ADR-0009), is worth deciding in AC0's ADR rather than discovering during
AC5.
