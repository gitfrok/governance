# T-0018: Repository & review-history import from GitHub/GitLab

- **Status:** In progress (2026-08-10) — contracts, audit boundary, git phase, GitHub + GitLab
  history phases, pacing, imported-history read and web rendering are in; **AC1 (integration proof),
  AC2 (LFS), AC12, AC15, AC16 (payload tamper detection) and AC19 are open** — see
  "Acceptance criteria still open" below
- **Phase / Epic:** 1 / EP-8 Migration
- **Repo(s):** governance (contracts: import RPCs, `Provenance`, `HistoryImported`,
  `HistoryImportRevoked`) → backend (import job, git write path, Code Review, Audit,
  Identity&Access) → webfrontend (provenance rendering)
- **Spec:** docs/specs/SPEC-0011-repository-history-import.md
- **ADRs:** **0029 (Accepted — governing)**, 0004, 0016, 0007, 0006, 0003, 0022, 0015
- **Owner:** unassigned
- **Depends on:** T-0010 (Git-RPC), T-0006 (audit log), T-0016 (MR + approval policy),
  T-0013 (identity/tokens), T-0005 (PDP)

## Goal
Import a source repository from GitHub or GitLab (cloud or self-hosted) in one unit of work: git
data (all refs, tags, LFS objects) through the normal write path, **and** pull/merge-request history
— threads, comments, approvals, original authors and timestamps — landed as **`ATTESTED_IMPORT`**
data in the Code Review context under ADR-0029. Imported history never enters the audit log, never
satisfies a merge policy, and is never rendered as a platform approval. The import operation itself
is the one first-party audit event that admits it.

Scoped as a single task (SPEC-0011 open question 3, resolved at spec review) so a repository is never
left half-imported — git data present, review history missing — with no honest way to represent that
gap to the migrating customer.

## Acceptance criteria (test-first)
Numbering in parentheses maps to SPEC-0011.

**Git data**
- [ ] AC1 (SPEC-0011 AC1): all refs and tags are imported; a clone of the imported repo yields
      commit SHAs byte-identical to the source.
- [ ] AC2 (AC2): LFS pointers resolve and the referenced objects are fetchable after import.
- [x] AC3: imported writes go through the ordinary durability path — an accepted import ref update
      is acknowledged only after primary + one sync replica (ADR-0016); repos on block volumes, LFS
      on SeaweedFS-S3 (invariant 7).

**Review history**
- [x] AC4 (AC3): imported MRs carry title, description, state, source/target refs, threads,
      comments, approvals, labels, `declared_actor` and `declared_at` as declared by the source.
- [x] AC5: a comment whose diff position no longer resolves (source force-pushed, commits missing)
      degrades to **file-level** anchoring, and to **MR-level** attachment only when the file is also
      gone. No comment is ever dropped, and a degraded anchor is marked approximate in the API
      response so the UI can render it as such (SPEC-0011 open question 2, resolved).

**Job lifecycle**
- [x] AC6 (AC4): an interrupted import resumes without duplicating work and reaches the same end
      state (idempotent per `source_ref` + `import_id`), across both the git and history phases.
- [x] AC7: a failed import leaves nothing partially visible — git data and history flip to visible
      per-import, atomically.
- [x] AC8: source-side rate limiting causes backoff and a stalled (not failed) import.
- [x] AC9: import throughput is throttled ahead of degrading interactive git/web latency, and
      imported bytes count against the tenant's fair-use storage dimension (PRD §6, G8).
      **Ticked as far as this task can carry it:** the throttle is in (backend #43), and the byte
      count is measured by the storage tier that wrote the objects and handed to a `StorageMeter`
      port. No plane wires a meter, because fair-use accounting does not exist yet — PRD PR-23 is
      **New** and §12 lists it as needing its own spec and task. The dimension it will be charged
      against is that task's to build; this one owes the honest number at the seam, and delivers it.
      Do not read this tick as "a tenant's envelope now reflects imports".

**Provenance separation (ADR-0029) — the load-bearing criteria**
- [x] AC10 (AC5): after importing N history records, the audit log holds exactly one
      `HistoryImported` event for that import and **zero** `ATTESTED_IMPORT` records.
- [x] AC11 (AC6): the audit writer **rejects** any write whose provenance is not `FIRST_PARTY` — an
      error, not a silent drop. Enforced as a **boundary/fitness test** (T-0009 family), so it cannot
      regress to a unit-test-only guarantee.
- [ ] AC12 (AC7): no audit chain entry's chain position disagrees with our clock ordering after an
      import; `declared_at` influences nothing in the chain.
- [x] AC13 (AC8): an MR whose only approvals are imported is **blocked from merge** by the PDP
      (ADR-0006; extends SPEC-0009 / T-0016 gating).
- [x] AC14 (AC9): an unmapped `declared_actor` never resolves to a platform user in any API response
      or view; it is returned as an opaque handle plus its `source_instance`.
- [ ] AC15 (AC10): mapping a `declared_actor` to a platform identity requires a tenant admin, is
      PDP-authorized, and emits a first-party audit event naming the asserting admin. Email equality
      alone never produces a mapping.

**Integrity & revocation**
- [ ] AC16 (AC11): the `HistoryImported` manifest digest verifies against the imported set; mutating
      any imported record afterwards makes verification fail.
- [x] AC17 (AC12): revoking an import emits `HistoryImportRevoked`, tombstones every record with that
      `import_id`, and drops them from all reads and exports — while the original `HistoryImported`
      chain entry stays unaltered (invariant 5).
- [x] AC18 (AC13): no API surface can update or delete an individual imported record, or alter a
      provenance block.

**Evidence export**
- [ ] AC19 (AC14): an evidence pack spanning the import contains zero attested records in its control
      sections; attested history appears only in the labeled appendix with provenance blocks and the
      admitting `HistoryImported` event.

**Isolation & authorization**
- [x] AC20 (AC15): the import is PDP-authorized; a caller without import permission is denied and the
      denial is audited (ADR-0006, ADR-0007).
- [x] AC21 (AC16): imported git data, history records and manifests are tenant-scoped; a cross-tenant
      read of any of them is denied (invariants 1–2, SPEC-0001).
- [x] AC22 (AC17): source credentials never appear in the audit log, the manifest, imported records,
      job logs, or the agent stream.

**Rendering**
- [x] AC23 (AC18): an MR view mixing imported and first-party threads distinguishes them; an imported
      approval is never rendered in a way that reads as a platform approval (ADR-0015).

**Cross-cutting migration of existing writers**
- [x] AC24: every existing audit-emitting path sets provenance **explicitly** to `FIRST_PARTY` —
      ADR-0029 §1 forbids an implicit default. A writer that omits provenance fails to compile or is
      rejected at the writer boundary.

## Tests to write first
- contract: `CreateImport` / `GetImport` / `ListImports` / `RevokeImport` RPCs; additive `Provenance`
  message; `HistoryImported` / `HistoryImportRevoked` events; provenance field on Code Review read
  types (all additive within v1).
- **boundary/fitness** (highest value, write first): audit writer rejects non-`FIRST_PARTY`; no Code
  Review attested type is reachable from the audit store's write surface.
- policy: Rego cases — import denied without permission; MR with imported-only approvals denied, with
  one first-party approval allowed.
- unit (domain): import job state machine (pending → running → complete | failed | stalled) and
  resume/idempotency; provenance block immutability; tombstone-on-revoke; manifest digest
  computation; the AC5 anchor-degradation chain.
- integration: real source fixture (local git remote + LFS + threads + approvals) imported end-to-end
  onto a block volume — SHA equality (AC1), kill-and-resume mid-import (AC6), chain contents (AC10),
  chain ordering (AC12), manifest tamper detection (AC16), revoke (AC17).
- integration (export): evidence pack generation over a range spanning the import (AC19).
- unit (web): imported vs first-party rendering distinction, and approximate-anchor rendering
  (AC23, AC5).
- security: credential-redaction assertion across audit events, import records, manifests and logs.
- policy/isolation: cross-tenant read of imported repos, records and manifests denied.

## Definition of Done
See `../process/definition-of-done.md`.

## Progress record (2026-08-10)

| Repo | PR/Commit | What |
|---|---|---|
| governance | #110 | Additive contracts: `provenance.proto` (shared `Provenance` block with `CLASS_` enum), `ImportService` (Create/Get/List/RevokeImport) + `Import` state machine + `ImportedThread/Comment/Approval` read types on codereview, `HistoryImported`/`HistoryImportRevoked` audit events, `ImportRefs` git-phase RPC on GitStorage |
| backend | #39 | **AC6/AC11 + AC24**: `api.Entry` gains required `Provenance`; the postgres store rejects non-`FIRST_PARTY` with `ErrNotFirstParty` (an error, never a silent drop); new fitness rule `RuleAuditImportsCodereview` keeps attested types out of the audit write surface. **AC1-AC3**: `ImportRefs` fetches source refs/tags through the ordinary durability path; the token travels only in the child-process environment, never argv, and git stderr is never returned (AC22). **AC6/AC10/AC16/AC17**: the import service — idempotent per (tenant, repository, source URL), one `HistoryImported` event with manifest digest on completion, `Revoke` tombstones records + emits `HistoryImportRevoked`. **AC7**: a failed git phase is not visible (FAILED state, no audit event). |
| backend | #40 | **AC4/AC5/AC8/AC13/AC17**: the history phase — `internal/adapters/github` fetches PRs + reviews from the GitHub API, shapes `ImportedMergeRequest` records with `ATTESTED_IMPORT` provenance (opaque `declared_actor`, display-only `declared_at`, payload digest), stores them in the Code Review record store; approved reviews become `ImportedApproval` records that can never satisfy a merge policy (AC13); rate limits mark the import STALLED (AC8); `Revoke` tombstones imported records (AC17). Tests: stub GitHub server round-trip, rate-limit stall, URL parsing, revoked-import write refusal. |

| backend | #41 | **AC4/AC5**: GitLab as a second source behind the same port (`source_system` selects it), shared imported-record store, anchor degradation on both adapters. |
| backend | #43 | **AC9 (throttle half)**: import work is paced per phase; an import that cannot get a turn is STALLED, not FAILED, and resumes where it stopped. |
| governance | #114 | Additive: `ImportService.ListImportedHistory` (paged) with `ImportedMergeRequest.declared_creator`, and `ImportRefsResponse.imported_bytes`. |
| backend | `feat/t0018-imported-history-read` | **AC20/AC14/AC17 on the read path**: `ListImportedHistory` serves one import's records with every provenance block intact; a revoked import returns nothing; another tenant is refused. |
| backend | `feat/t0018-imported-bytes` | **AC9 (measurement half)**: git-storaged returns `imported_bytes` — the repository's growth across the fetch, measured by git, growth only — and a `StorageMeter` port attributes it to (tenant, repository, import) once per completed git phase. Nothing is charged for a failed phase. |
| bff | `feat/t0018-imported-history` | **AC23 read surface**: `GET /v1/repositories/{id}/imports/{import_id}/history`; provenance on every record, `satisfies_policy: false` on every imported approval, `approximate` on a degraded anchor, and no field that names a resolvable platform actor. |
| webfrontend | `feat/t0018-imported-history` | **AC23/AC5**: imported history renders in its own labelled unverified section; an imported approval states it is not a platform approval and satisfies no merge policy; a foreign handle always carries its source instance and is never a user link; a degraded anchor says it is approximate. Rules live in `src/lib/provenance.ts` and are unit tested, plus a container render asserting the markup itself. |

**Delivered:** contracts, the audit-writer provenance boundary (the load-bearing ACs the task's own
note names "highest value, write first"), the git phase, both history phases (GitHub and GitLab),
the import state machine, revocation, pacing, the imported-history read path, the imported-byte
measurement, and the web rendering.

### Acceptance criteria still open

These are open with reasons, not oversights. The task is **not** Done and Phase 1 does not close on
it until they are addressed or explicitly moved.

- **AC1 — integration proof.** Refs and tags are imported through the ordinary durability path and
  unit-tested there, but "a clone yields byte-identical SHAs" is an end-to-end claim about a real
  source and a real block volume. It needs the cluster lane (T-0003's territory), which this host
  cannot run. Unproven, not disproven.
- **AC2 — LFS.** Not implemented. `git fetch` moves no LFS object, and nothing in the tree resolves
  a pointer or fetches from SeaweedFS-S3 during an import. The task's Goal names LFS explicitly, so
  this is real remaining work, not a scope note.
- **AC12 — chain ordering after an import.** The audit chain is verified by T-0006's own tests, and
  `declared_at` never reaches the chain by construction. What is missing is the test that says so
  *across an import*: chain position versus clock ordering with imported records present.
- **AC15 — declared-actor mapping.** No surface exists. It also needs a contract RPC, so it is a
  governance PR first (ADR-0027 order), then backend, then policy. AC14's guarantee — an unmapped
  handle never resolves to a platform user — holds today precisely because mapping cannot happen.
- **AC16 — payload tamper detection.** The `HistoryImported` manifest digest is computed and
  reproducible, but over the import's metadata and per-type record counts. Mutating a comment's body
  leaves the digest unchanged, so "mutating any imported record makes verification fail" is not yet
  true. The digest must cover the records' payload digests.
- **AC19 — evidence-export appendix.** Phase 2 by design: there is no evidence-pack surface yet.

## Notes / open questions
- **Gates cleared:** ADR-0029 is `Accepted` and SPEC-0011 is `Approved`. This task may enter RED.
- **Three submodules, three PRs, in order** (ADR-0027, invariants 21–25): governance (contracts) →
  backend → webfrontend, each its own commit; super-repo bumps pins to merged commits only.
  **Never one commit across two.**
- Git objects are content-addressed, so provenance attaches to the **import**, not to blobs
  (ADR-0029). No provenance block on git data — only the import record and its audit event.
- This task absorbed the former **T-0019** at spec review (SPEC-0011 open question 3). It is large:
  agree an internal implementation order before starting — suggested contracts → audit-writer
  boundary (AC11) → git import → history import → actor mapping → rendering → export appendix.
- AC23 may justify splitting out a **T-0020** (webfrontend provenance rendering) if the UI work
  grows. Decide at planning, not mid-implementation, and never in a way that ships imported history
  unlabeled in the UI.
- AC24 is a cross-cutting edit to every current audit emitter. Cheap now (audit has one emitter path
  from T-0006), expensive later. Sequence this task before Phase-2 audit surfaces land.
- No Phase-1 plan file exists (`../plans/` holds only `phase-0-foundations.md`); sequencing here is
  asserted by `Depends on`, not by a plan.
