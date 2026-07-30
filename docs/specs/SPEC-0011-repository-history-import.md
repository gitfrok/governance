# SPEC-0011: Repository & review-history import (GitHub/GitLab)

- **Status:** Draft — **blocked on ADR-0029 acceptance**
- **Owner:** platform
- **Context(s):** Repository/Git + Code Review + Audit (+ Identity&Access for actor mapping)
- **ADRs:** 0029 (Proposed — governing), 0007, 0006, 0004, 0016, 0003, 0022, 0015
- **Task(s):** T-0018 (repo + ref import), T-0019 (review-history import + provenance)
- **PRD:** PR-12 (requirement), PR-17/PR-18 (evidence-export consequences)

## Problem / context

A migrating customer's trial is blocked by two things: getting their code in, and not losing their
in-flight review backlog and past approval record. PR-12 requires importing refs, tags, LFS objects,
**and** pull/merge-request history — threads, approvals, original authors and timestamps — from
GitHub or GitLab (cloud or self-hosted).

Imported records are foreign assertions: the actor was never authenticated by us, the timestamp
predates the tenant, and the source instance's API returns whatever an admin there could have
edited. ADR-0029 governs the resolution: imported history is classified `ATTESTED_IMPORT`, lives in
the owning context, and never enters the append-only audit log (ADR-0007). This spec defines the
observable behavior of the import capability under that decision.

## In scope

- **Import job lifecycle:** create (source system, instance, credential, repo selection, scope),
  validate, run, observe progress, complete/fail, revoke.
- **Git data:** clone all refs and tags into the Git tier via the normal write path (ADR-0004,
  ADR-0016 — imports are ordinary pushes as far as durability is concerned); LFS objects fetched to
  blob storage.
- **Review history:** MRs/PRs with title, description, state, source/target refs, review threads
  and comments (including position/anchoring where the diff still resolves), approvals/reviews,
  labels, and their `declared_actor` + `declared_at`.
- **Provenance:** every imported non-git record carries the ADR-0029 provenance block; every import
  emits first-party `HistoryImported`; revocation emits `HistoryImportRevoked`.
- **Manifest:** a per-import manifest with a digest over the fetched payload set, and a verifier.
- **Actor mapping:** optional tenant-admin-asserted mapping from `declared_actor` to a platform
  identity, itself first-party audited; unmapped handles render as foreign.
- **Rendering rules:** imported records are visibly distinguishable from first-party records in MR
  and history views.

## Out of scope

- Issues, projects, wikis, releases, CI history, webhooks, branch-protection settings (issues/PM are
  a PRD §7 non-goal; the rest is later).
- Continuous mirroring / two-way sync — import is a one-shot, resumable operation.
- Self-service identity linking by the end user proving control of a source account (ADR-0029 §4
  allows it; only the admin-assertion path ships here).
- Export **out** of the platform.
- Importing from Bitbucket, Gitea, or plain bundles.

## Contracts touched

Additive within v1 (`contracts/README.md`):

- `contracts/events/audit/v1` — `HistoryImported`, `HistoryImportRevoked`.
- A shared `Provenance` message (per ADR-0029 §7) referenced by Code Review types.
- `contracts/proto/codereview/v1` — `Provenance` field on MR/thread/approval read types.
- Import RPCs (`CreateImport`, `GetImport`, `ListImports`, `RevokeImport`) in the owning context's
  proto package.

No breaking change to existing messages; provenance is an added field with `FIRST_PARTY` as the
meaning of records written by existing paths, set explicitly by those writers (ADR-0029 §1: no
implicit default at the writer).

## Data owned

- **Repository/Git** owns refs, objects, LFS blobs — indistinguishable from pushed data (git objects
  are content-addressed; provenance attaches to the *import*, not to blobs).
- **Code Review** owns imported MRs/threads/approvals in its own schema, tenant-scoped (ADR-0003),
  with the provenance block; append-only within the context, tombstoned on revoke.
- **Audit** owns `HistoryImported`/`HistoryImportRevoked` only. It stores **no** imported content.
- **Identity&Access** owns the verified/asserted actor mappings.

No cross-context table access (ADR-0022).

## Acceptance criteria (each becomes a test)

**Import happy path**
- [ ] AC1: Importing a source repo brings over all refs and tags; a clone of the imported repo
      yields byte-identical commit SHAs to the source.
- [ ] AC2: LFS pointers resolve; the referenced objects are fetchable after import.
- [ ] AC3: Imported MRs appear with title, description, state, refs, threads, comments, approvals,
      `declared_actor`, and `declared_at` preserved as declared.
- [ ] AC4: An interrupted import resumes without duplicating records (idempotent per
      `source_ref` + `import_id`).

**Provenance separation (ADR-0029) — the load-bearing tests**
- [ ] AC5: After an import of N history records, the audit log contains exactly one
      `HistoryImported` event for it and **zero** records with provenance `ATTESTED_IMPORT`.
- [ ] AC6: The audit writer **rejects** any attempted write whose provenance is not `FIRST_PARTY`
      (error, not silent drop). Enforced as a boundary/fitness test, not only a unit test.
- [ ] AC7: No audit chain entry's chain position disagrees with our clock ordering after an import —
      i.e. `declared_at` never influences chain order.
- [ ] AC8: An imported approval does **not** satisfy a required-reviewer approval policy: an MR whose
      only approvals are imported is blocked from merge by the PDP (ADR-0006, SPEC-0009).
- [ ] AC9: An unmapped `declared_actor` never resolves to a platform user in any API response or
      rendered view; it is returned as an opaque foreign handle with its `source_instance`.
- [ ] AC10: Mapping a `declared_actor` to a platform identity requires a tenant admin, is PDP-
      authorized, and emits a first-party audit event naming the asserting admin. Email equality
      alone never produces a mapping.

**Integrity & revocation**
- [ ] AC11: The `HistoryImported` manifest digest verifies against the imported record set;
      mutating any imported record afterwards makes verification fail.
- [ ] AC12: Revoking an import emits `HistoryImportRevoked`, tombstones every record with that
      `import_id`, and removes them from all reads/exports — while the original `HistoryImported`
      event remains in the chain unaltered (invariant 5).
- [ ] AC13: No API surface exists to update or delete an imported record individually, or to alter
      its provenance block.

**Evidence export (PR-17)**
- [ ] AC14: A generated evidence pack over a range spanning an import contains zero attested records
      in its control sections; attested history appears only in the labeled appendix with its
      provenance blocks and the admitting `HistoryImported` event.

**Isolation & authorization**
- [ ] AC15: An import is authorized by the PDP; a caller without import permission is denied and the
      denial is audited.
- [ ] AC16: Imported data is tenant-scoped — a cross-tenant read of any imported record or manifest
      is impossible (SPEC-0001).
- [ ] AC17: Source credentials supplied for an import are never written to the audit log, the
      manifest, imported records, or the agent stream (invariant on secrets).

**Rendering (ADR-0015)**
- [ ] AC18: An MR view containing both imported and first-party threads distinguishes them, and an
      imported approval is never rendered in a way that reads as a platform approval.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | imported records tenant-scoped under RLS; per-tenant manifests (AC16) |
| G2 least privilege | import and actor-mapping are PDP-authorized; denials audited (AC10, AC15) |
| G4 change governance | imported approvals cannot gate a merge; only first-party approvals satisfy policy (AC8) |
| G5 auditability | the import is a first-party chained event; attested content stays out of the chain (AC5–AC7, AC12) |
| G6 compliance | evidence packs keep control claims to witnessed events; attested history is labeled and excluded (AC14) |

## Non-functional

- Import is asynchronous and resumable; progress observable per phase (git, LFS, history) with
  record counts.
- Import load must not degrade interactive git or web latency for the tenant beyond the §9 PRD
  targets — imports are throttled ahead of degrading normal traffic, and count against the
  tenant's fair-use storage dimension.
- Source-side rate limits are respected with backoff; a rate-limited import stalls rather than fails.
- Manifest verification is offline/batchable (as with the audit verifier, SPEC-0003).
- A failed import leaves no partially visible history: records become visible per-import atomically.

## Open questions / assumptions

1. **Blocked on ADR-0029.** This spec cannot go `Approved` while the governing ADR is `Proposed`.
2. **Comment anchoring** when the imported diff no longer resolves (force-pushed or missing source
   commits): assume degrade to file-level or MR-level attachment rather than dropping the comment —
   confirm during review.
3. **Task split** T-0018 / T-0019 assumed (git data, then history+provenance) so refs-only import can
   ship first; confirm against the Phase-1 sequence, since PR-12 was scoped into Phase 1 after the
   plan was written and `../plans/` has no Phase-1 plan file yet.
4. **Retention** of attested records follows repo retention, not audit retention (ADR-0029
   follow-up); the audit retention policy itself is still an ADR-0007 follow-up.
5. Assumes source credentials are a tenant-supplied PAT/OAuth token with read scope; credential
   storage reuses the platform secret path (no new secret store).
6. Volume assumption: a single repo import fits the PRD §9 ceiling (≤20 GB, and MR history in the
   tens of thousands of records). Larger sources are a cells/Phase-2 conversation.
