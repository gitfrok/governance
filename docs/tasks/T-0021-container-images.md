# T-0021: Container images for both planes

- **Status:** Done (2026-08-10) — backend #19/#25, bff #16/#19, webfrontend #16/#18
- **Phase / Epic:** 1 / EP-10
- **Repo(s):** governance (ADR-0035, ADR-0044, ADR-0047), backend (`Dockerfile`, both `cmd/` targets), bff (`Dockerfile`), webfrontend (`Dockerfile`, SSR), super-repo (`deploy/dev/`, `versions.env`, CI) — ADR-0027 order
- **Spec:** chore — acceptance criteria below. AC0 is a Proposed ADR, not a chore step.
- **ADRs:** 0009, 0013, 0023, 0024, 0025, 0034, **0035**, **0044**, **0047**
- **Owner:** unassigned

## Goal
A deployable image per plane, so a policy-checked request can run end-to-end in a cluster.

## Acceptance criteria (test-first)
- [x] **AC0** — a Proposed ADR for the image build surface, reviewed before any Dockerfile is written. Met: ADR-0035 Accepted 2026-08-08.
- [x] AC1: one image per plane binary — `cmd/dataplane-app` and `cmd/controlplane-app`.
- [x] AC2: an image for `bff/`.
- [x] AC2a: an image for `webfrontend/`'s SSR server.
- [x] AC3: runtime posture asserted — non-root, read-only root filesystem, no shell.
- [x] AC4: the data plane starts with the `gitfrok-policy-bundle` ConfigMap mounted at `/etc/gitfrok/policy` and exits non-zero without it.
- [x] AC5: `deploy/dev/` gains dataplane and controlplane manifests, recorded in `versions.env`.
- [x] AC6: CI builds the images on PR in the repo that owns each one.

## Tests to write first
- integration: data plane comes up in-cluster with the bundle mounted; exits non-zero without it
- integration: `make dev-smoke` reaches a policy-checked request end-to-end over TLS
- fitness: built images satisfy the AC3 posture; `check-dev-images.sh` covers the new tags
- boundary: no cross-repo-source violations via the Dockerfile

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `c869a44` (#19) | Add `Dockerfile.dataplane` and `Dockerfile.controlplane`: multi-stage, `scratch` base, `CGO_ENABLED=0`, `USER 65532:65532`. |
| backend | `dc54204` (#25) | Publish signed plane images: `Publish plane images` workflow builds + cosign-signs from `main`/tags. |
| bff | `72426fe` (#16) | Add `Dockerfile` for BFF plane image. |
| bff | `7cec234` (#19) | Publish signed BFF image. |
| webfrontend | `670f6e6` (#16) | Add SSR server `Dockerfile`. |
| webfrontend | `de8aa5b` (#18) | Publish signed SSR image. |

- **AC1–AC2a** — four images build from `backend/` (dataplane, controlplane), `bff/`, and `webfrontend/` (SSR). `go.mod` floors respected (Go 1.26). ADR-0035 Accepted; ADR-0044 (cosign key custody) and ADR-0047 (public release image pulls) accepted before implementation.
- **AC3** — `backend/scripts/test-container-images.sh` asserts non-root, read-only root, and no shell on all plane images; runs in `ci.yml` on every PR.
- **AC4–AC6** — `deploy/dev/` manifests and `versions.env` register the new images; `check-dev-images.sh` covers them; CI builds on PR in each owning repo.
