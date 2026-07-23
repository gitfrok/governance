# T-0001: Scaffold super-repo + submodules (polyrepo + HCLC)

- **Status:** In Review (implementation complete; PRs per submodule pending)
- **Phase / Epic:** 0 / EP-0
- **Repo(s):** super-repo + governance + backend + bff + webfrontend
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0027, 0025, 0022, 0023, 0028
- **Owner:** unassigned

## Goal
Stand up the AGDD repository topology and the modular-monolith layout so every later task has a
correct home and enforced boundaries from commit one.

## Acceptance criteria (test-first)
- [x] AC1: Super-repo composes four submodules (`governance`, `backend`, `bff`, `webfrontend`)
      via `.gitmodules`; `make bootstrap` initializes them from a clean clone. (Relative URLs
      resolve under the `gitfrok` org; `scripts/bootstrap.sh` wired.)
- [x] AC2: `backend` has the modular-monolith tree — `modules/<ctx>/api/` +
      `modules/<ctx>/internal/{domain,app,adapters}/`, `cmd/{dataplane-app,controlplane-app}`,
      `platform/{ids,bus,telemetry}`; `go.mod` declares `go 1.26`. (`repository` context seeded.)
- [x] AC3: `bff` (Go, `go 1.26`) and `webfrontend` (Astro; `engines.node>=26`, TypeScript 7)
      baselines build. (`go build ./...`, `astro build`, `tsc --noEmit` all green.)
- [x] AC4: `governance` holds `contracts/`, `policies/`, `docs/`; `buf` generates **Go**
      (backend, bff) and **TS** (webfrontend) from `contracts/` into each consumer's `gen/`.
      (`buf.yaml` in contracts; per-consumer `buf.gen.yaml` with managed-mode go_package prefix;
      `make codegen`.)
- [x] AC5: A dependency-direction check stub exists (extended by T-0002): reverse edges fail.
      (`scripts/check-dep-direction.sh` + `backend/internal/arch` fitness test with a rejected
      fixture; `make verify`.)

## Tests to write first
- boundary: a fixture that violates the one-way direction (invariant 22) must fail the build.
- contract: codegen succeeds for both protos into Go and TS.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Real submodule URLs replace the `.gitmodules` placeholders. Follow the AGDD loop.
