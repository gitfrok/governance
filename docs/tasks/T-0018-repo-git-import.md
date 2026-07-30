# T-0018: Repository import — refs, tags & LFS from GitHub/GitLab

- **Status:** Blocked (SPEC-0011 must be Approved; ADR-0029 is now Accepted)
- **Phase / Epic:** 1 / EP-8 Migration
- **Repo(s):** governance (contracts: import RPCs) → backend (import job + git write path)
- **Spec:** docs/specs/SPEC-0011-repository-history-import.md
- **ADRs:** 0004, 0016, 0006, 0003, 0022, 0029
- **Owner:** unassigned
- **Depends on:** T-0010 (Git-RPC), T-0013 (identity/tokens), T-0005 (PDP)
- **Blocks:** T-0019

## Goal
Import a source repository's git data — all refs, tags and LFS objects — from GitHub or GitLab
(cloud or self-hosted) into the Git tier via the normal write path, as a resumable, PDP-authorized,
audited job. Code-only: no review history (that is T-0019).

## Acceptance criteria (test-first)
- [ ] AC1 (SPEC-0011 AC1): all refs and tags are imported; a clone of the imported repo yields
      commit SHAs byte-identical to the source.
- [ ] AC2 (AC2): LFS pointers resolve and the referenced objects are fetchable after import.
- [ ] AC3 (AC4): an interrupted import resumes without duplicating work and reaches the same end
      state (idempotent per `source_ref` + `import_id`).
- [ ] AC4 (AC15): the import is PDP-authorized; a caller without import permission is denied and the
      denial is audited (ADR-0006, ADR-0007).
- [ ] AC5 (AC16): imported git data is tenant-scoped; a cross-tenant read of the repo or its import
      record is denied (invariants 1–2).
- [ ] AC6 (AC17): source credentials never appear in the audit log, the import record, job logs, or
      the agent stream.
- [ ] AC7: imported writes go through the ordinary durability path — an accepted import ref update
      is acknowledged only after primary + one sync replica (ADR-0016); repos on block volumes, LFS
      on SeaweedFS-S3 (invariant 7).
- [ ] AC8: a failed import leaves no partially visible repository — visibility flips per-import.
- [ ] AC9: source-side rate limiting causes backoff and a stalled (not failed) import.
- [ ] AC10: import throughput is throttled ahead of degrading interactive git/web latency, and
      imported bytes count against the tenant's fair-use storage dimension (PRD §6, G8).

## Tests to write first
- contract: `CreateImport` / `GetImport` / `ListImports` RPC surface (additive within v1).
- unit (domain): import job state machine — pending → running → complete | failed | stalled;
  resume/idempotency logic.
- integration: real source fixture (local git remote + LFS) imported end-to-end onto a block volume;
  SHA equality assertion; kill-and-resume mid-import.
- policy/isolation: import denied without permission; cross-tenant repo handle denied.
- security: credential-redaction assertion across audit events, import records, and logs.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
- **Blocked:** ADR-0029 is `Accepted`, so the decision gate is clear; the remaining gate is
  SPEC-0011 going `Approved`. Do not enter RED before that (AGDD, ADR-0028).
- Cross-repo order per ADR-0027: governance PR (import RPCs) → backend implements and bumps the
  governance pointer → super-repo bumps pins to merged commits only.
- Git objects are content-addressed, so provenance attaches to the **import**, not to blobs
  (ADR-0029). This task therefore needs no provenance block on git data — only the audited import
  record. `HistoryImported` itself lands in T-0019 with the attested content it admits.
- No Phase-1 plan file exists (`../plans/` holds only `phase-0-foundations.md`); sequencing here is
  asserted by the task's `Depends on`, not by a plan.
