# T-0018: Repository & review-history import from GitHub/GitLab

- **Status:** In progress (2026-08-10) — contracts + audit boundary + git phase + GitHub history phase merged; web rendering remains
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
- [ ] AC3: imported writes go through the ordinary durability path — an accepted import ref update
      is acknowledged only after primary + one sync replica (ADR-0016); repos on block volumes, LFS
      on SeaweedFS-S3 (invariant 7).

**Review history**
- [ ] AC4 (AC3): imported MRs carry title, description, state, source/target refs, threads,
      comments, approvals, labels, `declared_actor` and `declared_at` as declared by the source.
- [ ] AC5: a comment whose diff position no longer resolves (source force-pushed, commits missing)
      degrades to **file-level** anchoring, and to **MR-level** attachment only when the file is also
      gone. No comment is ever dropped, and a degraded anchor is marked approximate in the API
      response so the UI can render it as such (SPEC-0011 open question 2, resolved).

**Job lifecycle**
- [ ] AC6 (AC4): an interrupted import resumes without duplicating work and reaches the same end
      state (idempotent per `source_ref` + `import_id`), across both the git and history phases.
- [ ] AC7: a failed import leaves nothing partially visible — git data and history flip to visible
      per-import, atomically.
- [ ] AC8: source-side rate limiting causes backoff and a stalled (not failed) import.
- [ ] AC9: import throughput is throttled ahead of degrading interactive git/web latency, and
      imported bytes count against the tenant's fair-use storage dimension (PRD §6, G8).

**Provenance separation (ADR-0029) — the load-bearing criteria**
- [ ] AC10 (AC5): after importing N history records, the audit log holds exactly one
      `HistoryImported` event for that import and **zero** `ATTESTED_IMPORT` records.
- [ ] AC11 (AC6): the audit writer **rejects** any write whose provenance is not `FIRST_PARTY` — an
      error, not a silent drop. Enforced as a **boundary/fitness test** (T-0009 family), so it cannot
      regress to a unit-test-only guarantee.
- [ ] AC12 (AC7): no audit chain entry's chain position disagrees with our clock ordering after an
      import; `declared_at` influences nothing in the chain.
- [ ] AC13 (AC8): an MR whose only approvals are imported is **blocked from merge** by the PDP
      (ADR-0006; extends SPEC-0009 / T-0016 gating).
- [ ] AC14 (AC9): an unmapped `declared_actor` never resolves to a platform user in any API response
      or view; it is returned as an opaque handle plus its `source_instance`.
- [ ] AC15 (AC10): mapping a `declared_actor` to a platform identity requires a tenant admin, is
      PDP-authorized, and emits a first-party audit event naming the asserting admin. Email equality
      alone never produces a mapping.

**Integrity & revocation**
- [ ] AC16 (AC11): the `HistoryImported` manifest digest verifies against the imported set; mutating
      any imported record afterwards makes verification fail.
- [ ] AC17 (AC12): revoking an import emits `HistoryImportRevoked`, tombstones every record with that
      `import_id`, and drops them from all reads and exports — while the original `HistoryImported`
      chain entry stays unaltered (invariant 5).
- [ ] AC18 (AC13): no API surface can update or delete an individual imported record, or alter a
      provenance block.

**Evidence export**
- [ ] AC19 (AC14): an evidence pack spanning the import contains zero attested records in its control
      sections; attested history appears only in the labeled appendix with provenance blocks and the
      admitting `HistoryImported` event.

**Isolation & authorization**
- [ ] AC20 (AC15): the import is PDP-authorized; a caller without import permission is denied and the
      denial is audited (ADR-0006, ADR-0007).
- [ ] AC21 (AC16): imported git data, history records and manifests are tenant-scoped; a cross-tenant
      read of any of them is denied (invariants 1–2, SPEC-0001).
- [ ] AC22 (AC17): source credentials never appear in the audit log, the manifest, imported records,
      job logs, or the agent stream.

**Rendering**
- [ ] AC23 (AC18): an MR view mixing imported and first-party threads distinguishes them; an imported
      approval is never rendered in a way that reads as a platform approval (ADR-0015).

**Cross-cutting migration of existing writers**
- [ ] AC24: every existing audit-emitting path sets provenance **explicitly** to `FIRST_PARTY` —
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

**Delivered so far:** contracts, the audit-writer provenance boundary (the load-bearing ACs the
task's own note names "highest value, write first"), the git phase, the history phase (GitHub), the
import state machine, and revocation.

**Still open (remaining ACs):** the webfrontend provenance rendering (AC23, AC9), the
evidence-export appendix (AC19/AC14, Phase 2), and a GitLab source client (the GitHub importer is
wired; `source_system` selects it — GitLab is additive behind the same port). AC8 (imported
approvals never satisfy a merge policy) is enforced by the PDP rule set in `governance/policies`;
the merge path already feeds `valid_approvals` from first-party reviews only.

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
