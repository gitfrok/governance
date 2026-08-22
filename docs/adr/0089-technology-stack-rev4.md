# ADR-0089: Technology stack (rev. 4) — Go floor 1.27

- **Status:** Accepted
- **Date:** 2026-08-22
- **Supersedes:** ADR-0023
- **Governs:** operability, security, developer experience
- **Relates to:** ADR-0022 (modules), ADR-0024 (dev env), ADR-0027 (one submodule per commit),
  SPEC-0036 (modern Go idiom adoption)

## Context
ADR-0023 (rev. 3) pinned the Go floor at 1.26 with the stated goal of running current releases.
Go 1.27 is released and installed on the development host (`go1.26.0` is the active toolchain;
`1.27.0` is present in the toolchain directory alongside it). Every Go pin in the tree still
declares 1.26, so the floor and the available toolchain have drifted apart.

This revision changes one floor. Everything else in ADR-0023 — the request path, the service
choices, and the remaining version floors — is carried forward unchanged.

## Decision
1. **Raise the Go floor from 1.26 to 1.27.** Full floors table, superseding ADR-0023's:

| Component | Min version | Runs as |
|---|---|---|
| Go | **1.27** | host toolchain (`go.mod: go 1.27`) |
| Node.js | **26** | host + SSR runtime (`package.json engines`) |
| TypeScript (tsc) | **7** | build — native compiler |
| PostgreSQL | **18** | service (image) |
| Valkey | **9.1** | service (image) |
| Redpanda | **26.1** | service (image) |
| SeaweedFS | **4.40** | service (image) |
| git | **2.x** | host toolchain |

2. **Materialization is unchanged** from ADR-0023: host tools in `.tool-versions`, service image
   tags in `deploy/dev/versions.env`, `go.mod` and `package.json engines` mirroring the floors.

3. **The Go builder base image moves from Alpine 3.22 to Alpine 3.23**, in the same commits.
   This is not a separate choice: upstream publishes no `golang:1.27.0-alpine3.22`. The tags that
   exist are `1.27.0-alpine3.23` and `1.27.0-alpine3.24` (verified against the registry on
   2026-08-22 — `1.27.0-alpine3.22` returns 404). 3.23 is the smaller move and is taken.

   Scope: **build stages only.** Every Go image builds with `CGO_ENABLED=0` and ships either from
   `scratch` (controlplane, dataplane, operator, bff) or, for git-storaged, from its own separate
   `alpine:3.22.2` runtime stage. The builder base contributes nothing to any shipped layer and no
   musl linkage crosses the stage boundary, so this stays mechanical. **git-storaged's runtime
   `alpine:3.22.2` is not touched by this ADR** — that base carries the shipped `git`, and moving
   it is a decision about ADR-0048's exception, not about the Go floor.

4. **No idiom sweep in this ADR.** Raising the floor makes the Go 1.27 idioms *available*; it does
   not adopt them. Adoption is SPEC-0036's remit and is recorded as a follow-up below.

## Touchpoints
Every Go pin in the tree, enumerated so the implementation task is complete. Per ADR-0027
(invariants 21–25) these land as **three separate commits**, one per repository, plus the
super-repo pin bump.

**backend** (`1.26.0` → `1.27.0`):
- `.tool-versions` — `golang 1.26.0`
- `go.mod` — `go 1.26.0` (this file uses the three-component form; keep it)
- `Dockerfile.controlplane`, `Dockerfile.dataplane`, `Dockerfile.gitstoraged`,
  `Dockerfile.operator` — build stage `FROM docker.io/library/golang:1.26.0-alpine3.22 AS build`
  becomes `golang:1.27.0-alpine3.23`. `Dockerfile.gitstoraged`'s *runtime* stage
  (`FROM docker.io/library/alpine:3.22.2`, line 21) stays as it is — see decision 3
- `.github/workflows/ci.yml:27` — comment cites "ADR-0023 pins Go 1.26"

**bff** (`1.26` / `1.26.0` → `1.27` / `1.27.0`):
- `.tool-versions` — `golang 1.26.0`
- `go.mod` — `go 1.26` (this file uses the two-component form; keep it)
- `Dockerfile` — build stage `golang:1.26.0-alpine3.22` becomes `golang:1.27.0-alpine3.23`
- `.github/workflows/ci.yml:44` — comment cites "ADR-0023 pins Go 1.26"

**super-repo**:
- `.tool-versions` — `golang 1.26.0`
- `deploy/dev/versions.env:43` — host-floor comment `go>=1.26`
- `scripts/check-version-floors.sh:11` — `GO_FLOOR="1.26"`, the fitness function that fails the
  gate if a submodule's `go.mod` drifts below the floor. It must move in the same commit as the
  super-repo `.tool-versions`, or the gate contradicts the ADR in one direction or the other.
- submodule pins for backend and bff, once their commits exist

Neither Go submodule carries a golangci-lint config, so there is no `run.go` language-version
setting to move.

## Consequences
**Positive:** the floor matches a released, installed toolchain again; the 1.27 standard library
becomes available to specs that want it.

**Negative / watch-outs:**
- **The builder base had to move with the floor** (decision 3). Checked, not assumed: Alpine 3.22
  carries no Go 1.27 image, so there is no version of this bump that leaves the Dockerfiles alone.
  ADR-0023's standing instruction still applies to the new pin — `golang:1.27.0-alpine3.23` is
  confirmed present today and should be re-confirmed at build time.
- **Two Alpine versions now coexist in `Dockerfile.gitstoraged`**: a 3.23 builder and a 3.22.2
  runtime. That is intentional and inert here, but it means the file no longer reads as
  single-versioned, and a later reader may "fix" it. The comment added at the build stage should
  say why the two differ.
- **Go 1.27 is past the assistant knowledge boundary.** The idiom list below comes from the Modern
  Go Guidelines CLI resolved against 1.27, not from recall. Anything not on that list should be
  treated as unverified.
- **CI toolchain resolution.** Both workflows use `actions/setup-go@v7` reading the version from
  `go.mod`, so CI follows the `go.mod` bump without a workflow edit. Only the stale comments need
  touching.

- **Raising the floor rewrote generated code, and the generator pin did not prevent it.** Found
  when this bump first reached CI. `protoc-gen-go` stayed at its pinned v1.35.2; what moved is the
  Go standard library that *compiles* it. protoc-gen-go formats its output through `go/format`, and
  1.27's `go/format` no longer emits the blank `//` separator before an indented list inside a doc
  comment — six such lines across three files, in both backend and bff, and nothing else.

  So the super-repo's codegen gate holds the plugin *version* constant but not the toolchain that
  builds the plugin, and generated bytes are a function of the floor. Two consequences that are now
  rules: the regeneration commits belong to the same landing as the floor bump, and **anyone
  regenerating locally must build the generators with the floor toolchain** (`GOTOOLCHAIN=go1.27.0
  go install …@v1.35.2`) or they will see this diff in reverse and read it as drift.

  *Considered and rejected:* pinning the generator-build toolchain below the floor to keep generated
  bytes still. That trades one invisible coupling for another — CI would build generators with a
  toolchain this ADR just declared below the floor, it ages out when 1.26 leaves support, and every
  developer on the floor toolchain would see permanent local drift. The super-repo CI comment
  claiming the generator pin "is the thing this check holds constant" is accurate about the version
  and incomplete about the toolchain; this ADR is the record until that comment is corrected.

**Follow-ups (out of scope here):**
- A SPEC-0036 wave for the five idioms Go 1.27 adds: generic methods; promoted field names in
  struct literals for embedded fields; `strings.CutLast` / `bytes.CutLast`; the standard-library
  `uuid` package; `url.URL.Clone` / `url.Values.Clone`.
- `stdlib_uuid` may allow dropping a third-party UUID dependency from backend. **Check and defer** —
  a dependency removal is its own change with its own gates, not part of a floor bump.

## Alternatives considered
- **Stay on 1.26.** Rejected — ADR-0023's stated goal is to run current releases, and the host
  already carries 1.27.
- **Bump the floor and sweep the idioms in one change.** Rejected — mixes a floor decision with a
  code sweep across two submodules, which ADR-0027 forbids in one commit and which would make the
  floor change impossible to revert cleanly.
- **Amend ADR-0023 in place.** Rejected — ADR-0023 established the rev.-supersession pattern by
  superseding ADR-0020; a floor change is a decision with a date, not an edit.
