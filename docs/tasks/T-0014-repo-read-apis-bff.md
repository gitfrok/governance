# T-0014: Repository read APIs + BFF aggregation

- **Status:** Done (2026-08-10) — backend #22/#24; bff #18
- **Phase / Epic:** 1 / MVP
- **Repo(s):** backend + bff
- **Spec:** docs/specs/SPEC-0007-repo-read-bff-view.md
- **ADRs:** 0022, 0015
- **Owner:** unassigned

## Goal
Expose repo/file/tree/diff read APIs from backend and aggregate them for the UI in the BFF.

## Acceptance criteria (test-first)
- [x] AC1: backend gRPC returns tree, file blob, and diff for a ref (tenant-scoped).
- [x] AC2: the BFF aggregates these into the shaped view API — **no business logic** (invariant 18).
- [x] AC3: unauthorized file access is denied via the PDP.

## Tests to write first
- contract: backend gRPC + BFF surface against governance/contracts.
- unit (backend domain): diff/tree; bff: aggregation only (assert no domain logic).
- policy/isolation: private file access.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `3072b85` (#22) | Added the additive `RepositoryReader` gRPC implementation: signed, tenant/revision-bound tree cursors; bounded file/diff streams; path and revision validation; and a Repository/Git PDP preflight before any Git subprocess. |
| bff | `8cd01bb` (#18) | Added the gRPC adapter and aggregation-only reader port. It forwards verified identity context and maps only contract results; it has no storage, PDP, or Git logic. |
| backend | `32849a2` (#24) | Added the PDP-denial regression: an unauthorized file read returns the same coarse no-content response and does not start a Git subprocess. |

- **AC1** — backend integration tests use a seeded bare repository, paginate a tree, join 64 KiB-bounded file chunks, and stream a diff. A forged cursor and a wrong-tenant request yield no content.
- **AC2** — BFF unit and gRPC-adapter tests prove shaped results retain only `RepositoryReader` data and verified request context.
- **AC3** — `TestRepositoryReaderPDPDenialSendsNoFileContent` proves PDP denial occurs before a storage command; `go test -race ./git-storaged/...` and `go test -race ./...` passed for the merged slices.

## Notes / open questions
SPEC-0007 and the additive SPEC-0017 contract were approved before implementation. Cross-repo changes landed governance-first under ADR-0027.
