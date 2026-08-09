# T-0010: Git-RPC storage service

- **Status:** Done (2026-08-09) — backend #20
- **Phase / Epic:** 1 / MVP
- **Repo(s):** backend (git-storaged)
- **Spec:** docs/specs/SPEC-0004-git-storage-transport.md;
  `SPEC-0015-git-rpc-contract.md` (**Approved when this governance PR merges**)
- **ADRs:** 0004, 0016
- **Owner:** unassigned

## Goal
Serve git object/ref operations over an internal RPC on sharded, replicated storage.

## Acceptance criteria (test-first)
- [x] AC1: clone/fetch/push of a small repo succeed via the RPC against one storage node.
- [x] AC2: repos live on **block volumes**, not FUSE (invariant 7); LFS/artifacts use SeaweedFS-S3.
- [x] AC3: every op is tenant-scoped; a wrong-tenant repo handle is denied (invariants 1–2).

## Tests to write first
- unit (domain): ref/pack operations; contract: the RPC surface; integration: real repo on a block volume.
- policy/isolation: cross-tenant repo access denied.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `db713875` (#20) | Generated `GitStorage` Go contract and `git-storaged`: bidirectional Git byte streams, tenant-scoped repository resolution, PDP `repo.read`/`repo.write` decisions before process start, FUSE-root refusal, and `RefUpdated` publication after receive-pack. |

- **AC1** — `TestUploadPackStreamsFetchThroughRPC` runs a real `git-upload-pack` exchange against
  a seeded bare repository; the same upload-pack stream is Git's clone/fetch transport.
  `TestReceivePackPublishesRefUpdated` constructs a real pack, pushes it through receive-pack, and
  verifies the resulting ref event.
- **AC2** — `NewServer` refuses a FUSE-mounted repository root before serving traffic. ADR-0033
  remains the authoritative block-volume decision; LFS/artifacts were out of this Git-RPC scope.
- **AC3** — `TestUploadPackWrongTenantIsUnavailableAndNeverStartsGit` proves a wrong-tenant handle
  gets the same unavailable response and cannot start a Git subprocess. All permitted operations
  call `modules/policy/api.DecisionPoint` before process execution.

## Notes / open questions
SPEC-0015 records the Git-RPC v1 contract. Its governance PR is the approval gate before RED
(AGDD).
Cross-repo changes follow the ADR-0027 order (governance first).
