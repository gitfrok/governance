# T-0019: Review-history import + attested provenance

- **Status:** Blocked (SPEC-0011 must be Approved; ADR-0029 is now Accepted)
- **Phase / Epic:** 1 / EP-8 Migration
- **Repo(s):** governance (contracts: `Provenance`, `HistoryImported`, `HistoryImportRevoked`) →
  backend (Code Review + Audit + Identity&Access) → webfrontend (provenance rendering)
- **Spec:** docs/specs/SPEC-0011-repository-history-import.md
- **ADRs:** **0029 (Accepted — governing)**, 0007, 0006, 0003, 0022, 0015
- **Owner:** unassigned
- **Depends on:** T-0018, T-0006 (audit log), T-0016 (MR + approval policy), T-0013 (identity)

## Goal
Import pull/merge-request history — threads, comments, approvals, original authors and timestamps —
and land it as **`ATTESTED_IMPORT`** data in the Code Review context under ADR-0029: never in the
audit log, never able to satisfy a merge policy, never rendered as a platform approval. The import
operation itself becomes the one first-party audit event that admits it.

## Acceptance criteria (test-first)
Numbering follows SPEC-0011.

**Import**
- [ ] AC1 (SPEC-0011 AC3): imported MRs carry title, description, state, source/target refs, threads,
      comments, approvals, labels, `declared_actor` and `declared_at` as declared by the source.
- [ ] AC2 (AC4): resumable and idempotent per `source_ref` + `import_id`.

**Provenance separation — the load-bearing criteria (ADR-0029)**
- [ ] AC3 (AC5): after importing N history records, the audit log holds exactly one
      `HistoryImported` event for that import and **zero** `ATTESTED_IMPORT` records.
- [ ] AC4 (AC6): the audit writer **rejects** any write whose provenance is not `FIRST_PARTY` —
      an error, not a silent drop. Enforced as a **boundary/fitness test** (T-0009 family), so it
      cannot regress to a unit-test-only guarantee.
- [ ] AC5 (AC7): no audit chain entry's chain position disagrees with our clock ordering after an
      import; `declared_at` influences nothing in the chain.
- [ ] AC6 (AC8): an MR whose only approvals are imported is **blocked from merge** by the PDP
      (ADR-0006; extends SPEC-0009 / T-0016 gating).
- [ ] AC7 (AC9): an unmapped `declared_actor` never resolves to a platform user in any API response
      or view; it is returned as an opaque handle plus its `source_instance`.
- [ ] AC8 (AC10): mapping a `declared_actor` to a platform identity requires a tenant admin, is
      PDP-authorized, and emits a first-party audit event naming the asserting admin. Email equality
      alone never produces a mapping.

**Integrity & revocation**
- [ ] AC9 (AC11): the `HistoryImported` manifest digest verifies against the imported set; mutating
      any imported record afterwards makes verification fail.
- [ ] AC10 (AC12): revoking an import emits `HistoryImportRevoked`, tombstones every record with
      that `import_id`, and drops them from all reads and exports — while the original
      `HistoryImported` chain entry stays unaltered (invariant 5).
- [ ] AC11 (AC13): no API surface can update or delete an individual imported record, or alter a
      provenance block.

**Evidence export**
- [ ] AC12 (AC14): an evidence pack spanning the import contains zero attested records in its
      control sections; attested history appears only in the labeled appendix with provenance blocks
      and the admitting `HistoryImported` event.

**Rendering**
- [ ] AC13 (AC18): an MR view mixing imported and first-party threads distinguishes them; an imported
      approval is never rendered in a way that reads as a platform approval (ADR-0015).

**Cross-cutting migration of existing writers**
- [ ] AC14: every existing audit-emitting path sets provenance **explicitly** to `FIRST_PARTY` —
      ADR-0029 §1 forbids an implicit default. A writer that omits provenance fails to compile or is
      rejected at the writer boundary.

## Tests to write first
- contract: additive `Provenance` message; `HistoryImported` / `HistoryImportRevoked` events;
  provenance field on Code Review read types.
- **boundary/fitness** (highest value, write first): audit writer rejects non-`FIRST_PARTY`;
  no Code Review attested type is reachable from the audit store's write surface.
- policy: Rego case — MR with imported-only approvals denied; with one first-party approval allowed.
- unit (domain): provenance block immutability; tombstone-on-revoke; manifest digest computation.
- integration: import a source fixture with threads + approvals; assert chain contents (AC3),
  chain ordering (AC5), manifest tamper detection (AC9), revoke behavior (AC10).
- integration (export): evidence pack generation over a range spanning the import (AC12).
- unit (web): imported vs first-party rendering distinction (AC13).
- policy/isolation: cross-tenant read of imported records and manifests denied.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
- **Decision gate cleared:** ADR-0029 is `Accepted`. Do not enter RED until SPEC-0011 is also
  `Approved` (ADR-0028).
- **Three submodules, three PRs, in order** (ADR-0027, invariants 21–25): governance (contracts)
  → backend → webfrontend, each its own commit; super-repo bumps pins to merged commits only.
  **Never one commit across two.**
- AC13/AC14 may justify splitting out a **T-0020** (webfrontend provenance rendering) if the UI work
  grows — decide at planning, not mid-implementation.
- AC14 is a cross-cutting edit to every current audit emitter. Cheap now (audit has one emitter path
  from T-0006), expensive later. Sequence this task before Phase-2 audit surfaces land.
- Comment anchoring when the imported diff no longer resolves is SPEC-0011 open question 2 — assumed
  degrade to file-level/MR-level attachment; confirm at spec review before writing AC1's test.
