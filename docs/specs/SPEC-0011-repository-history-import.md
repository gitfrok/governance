# SPEC-0011: Repository & review-history import (GitHub/GitLab)

- **Status:** Implemented (2026-08-11) — every acceptance criterion is proven by its task(s)
- **Owner:** platform
- **Context(s):** Repository/Git + Code Review + Audit (+ Identity&Access for actor mapping)
- **ADRs:** 0029 (Accepted — governing), 0007, 0006, 0004, 0016, 0003, 0022, 0015
- **Task(s):** T-0018 (repository + review-history import — git data and history in one unit)
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
  labels, and their `declared_actor` + `declared_at`. Where a comment's position no longer resolves,
  anchoring **degrades** — file-level, then MR-level — and the comment is never dropped (AC19).
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

**Anchor degradation**
- [ ] AC19: A comment whose diff position no longer resolves degrades to file-level anchoring, and to
      MR-level attachment only when the file is also gone. No comment is dropped, and the API marks a
      degraded anchor as approximate so the UI can render it as such.

**Read surface** (added 2026-08-10; AC18 requires a rendered view and nothing served the records it
renders. The criterion it depends on was implicit, which is how a read path with no test came close
to shipping.)
- [ ] AC20: Imported history is readable per import: a reader within the owning tenant retrieves the
      import's merge requests with their threads, approvals and provenance blocks. A read outside the
      tenant is refused, a read without import-read permission is denied at the PDP, and a revoked
      import returns nothing (which is AC12 observed on the read path, not a second rule).

**Actor mapping** (added 2026-08-10; AC10 named the rule but no criterion said what the surface
must refuse, and a mapping surface that is merely "PDP-authorized" can still quietly upgrade an
imported approval into a platform one.)
- [ ] AC22: Mapping is an assertion, not an inference. `MapDeclaredActor` records a named tenant
      admin's claim that a `(declared_actor, source_instance)` pair is a platform `actor_id`; the
      pair is scoped to its instance, because the same handle on two source instances is two people.
      No email comparison, string similarity, or bulk heuristic may produce a mapping, and there is
      no path that creates one without an admin's identity attached.
- [ ] AC23: A mapping never changes provenance. After a mapping, the imported record still reads as
      `ATTESTED_IMPORT`, an imported approval still satisfies no merge policy, and no read surface
      presents a mapped handle as an actor this platform witnessed. A mapping changes the label a
      reader sees, never the class of the record.
- [ ] AC24: The mapping is stored beside the imported records, never inside them: an imported record
      is immutable (AC13), so a mapping is a later first-party claim *about* it, and revoking the
      import drops the mapping from reads with the records it describes.

**Import cost** (added 2026-08-10; the NFR "imports … count against the tenant's fair-use storage
dimension" had no criterion, so nothing could fail if imports were free.)
- [ ] AC21: The bytes an import writes for a tenant are reported by the storage tier that wrote them
      and charged to that tenant's fair-use storage dimension. An import that fetches nothing charges
      nothing. Import work is paced: a step of import work waits before it runs, so an import yields
      throughput to the interactive git and web traffic it shares a plane with, and a paced-out import
      stops rather than proceeding unthrottled.

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

Questions 1–3 were **resolved at spec review** (2026-07-30) and are recorded here rather than
deleted, so the approved shape stays traceable.

1. ~~**Blocked on ADR-0029.**~~ **Resolved** — ADR-0029 is `Accepted`.
2. ~~**Comment anchoring** when the imported diff no longer resolves.~~ **Resolved** — degrade
   file-level, then MR-level; never drop the comment; mark the anchor approximate. Now normative as
   AC19.
3. ~~**Task split** T-0018 / T-0019.~~ **Resolved — rejected.** Git data and review history ship as
   **one task (T-0018)**; the former T-0019 was folded into it. A repository whose code is present
   but whose review history is not has no honest representation for the migrating customer, and
   PR-12's value is the history. T-0019 is retired and its number is not reused.
4. **Retention** of attested records follows repo retention, not audit retention (ADR-0029
   follow-up); the audit retention policy itself is still an ADR-0007 follow-up. **Still open** — it
   does not block implementation, since nothing here writes a retention policy, but the attested-record
   retention rule must exist before Phase-2 evidence-export work relies on it.
5. Assumes source credentials are a tenant-supplied PAT/OAuth token with read scope; credential
   storage reuses the platform secret path (no new secret store).
6. Volume assumption: a single repo import fits the PRD §9 ceiling (≤20 GB, and MR history in the
   tens of thousands of records). Larger sources are a cells/Phase-2 conversation.
