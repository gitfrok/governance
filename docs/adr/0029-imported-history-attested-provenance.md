# ADR-0029: Imported history is attested, not audited — two-class provenance

- **Status:** Accepted
- **Date:** 2026-07-31
- **Deciders:** platform, security/compliance
- **Governs:** G5 auditability, G6 compliance, G1 tenant isolation, G2 least privilege
- **Relates to:** ADR-0007 (append-only audit log), ADR-0006 (PDP), ADR-0022 (HCLC), ADR-0003
  (tenancy/RLS) · **PRD:** PR-12, PR-17, PR-18 (`../product/PRD.md`)

## Context

PR-12 requires importing a repository from GitHub/GitLab including **pull/merge request history —
review threads, approvals, and their original authors and timestamps**. That history is the buyer's
reason to migrate: an in-flight review backlog and a record of past approvals.

This collides with ADR-0007 and invariant 5. Our audit log is append-only and hash-chained, and its
value as evidence rests on one property: **every entry records something our system witnessed**, in
our clock order, attributable to a principal our PDP authenticated (ADR-0006). Imported records
have none of that:

- The **actor** is a foreign account handle. We never authenticated it. `alice` on the source
  instance may or may not be the `alice` in the customer's IdP, and the mapping is asserted by
  whoever ran the import.
- The **timestamp** predates the tenant's existence in our system. Writing it into a hash-chained
  log means either backdating entries (destroying chain-order integrity, and creating a
  history-forgery primitive) or entries whose chain position and content-time disagree.
- The **assertion itself is unverified**. A source instance's API returns what an admin there could
  have edited. We can attest *what we fetched*; we cannot attest *that it happened*.

If imported records land in the audit trail indistinguishably from first-party events, the trail
stops being evidence: an attacker or a careless migration can manufacture "a security lead approved
this merge in 2024", and PR-17's SOC 2 walkthrough would be built on unverifiable input. Conversely,
dropping the history makes PR-12 worthless. A decision is required before the import spec is written.

## Decision

We will introduce **two provenance classes** for historical records and keep them physically and
semantically separate.

### 1. Provenance is an explicit, non-optional classification

Every historical record carries `provenance`, one of:

- **`FIRST_PARTY`** — an event our services witnessed: actor authenticated by us, authorized by the
  PDP, timestamped by our clock. **Only these enter the audit log** (ADR-0007).
- **`ATTESTED_IMPORT`** — a record asserted by a foreign system and copied by us. Never enters the
  audit log.

There is no third class and no default. A writer that cannot state provenance cannot write.

### 2. Attested records live in the owning bounded context, not in Audit

Imported MR/PR history is **domain data of the Code Review context** (ADR-0022), stored in that
context's own schema and tenant-scoped like all other rows (ADR-0003). Audit does not own it, does
not chain it, and does not export it as control evidence.

Every attested record carries an immutable provenance block:

| Field | Meaning |
|---|---|
| `source_system`, `source_instance` | e.g. `github`, `github.example.com` |
| `source_ref` | the foreign object's stable ID/URL |
| `declared_actor` | the foreign handle **as an opaque string** |
| `declared_at` | the timestamp the source asserted |
| `import_id` | the import operation that produced this record |
| `payload_digest` | hash of the fetched payload as received |

`declared_at` is never written into any field our system treats as an occurrence time it vouches
for, and never used to order anything in the audit chain.

### 3. The **import** is a first-party audit event; the imported content is not

One import produces exactly one (or one per repository) `HistoryImported` **first-party** audit
event, chained normally, recording: the authenticated operator who ran it, PDP decision, source
system and instance, scope imported, record counts per type, and a **manifest digest** over the
imported payload set. This is the auditable fact — "this operator imported this attested set from
there at this time" — and it is verifiable.

The imported records are then reproducible against the manifest digest: we can prove nobody altered
the set after import, without claiming the set is true.

### 4. Foreign identities do not become first-party principals implicitly

`declared_actor` stays an opaque foreign handle. It may be **linked** to a platform identity only via
a **verified mapping** — the target user proves control of the source account, or a tenant admin
asserts the mapping and that assertion is itself a first-party audit event naming the asserting
admin. UI must render an unverified `declared_actor` as a foreign handle, never as a platform user,
and never in a way that reads as a platform approval.

An imported approval **never satisfies** a policy requirement (ADR-0006). Approvals that gate a
merge must be first-party. Imported approvals are display-only history.

### 5. Immutability without a delete path in the chain

Attested records are append-only within their context. A bad import is corrected by **revoking the
import** — a first-party audit event referencing `import_id`, after which the records are tombstoned
and excluded from all views and exports. No audit chain entry is ever edited or removed
(invariant 5); revocation is a forward-only act.

### 6. Evidence exports separate the two classes

Evidence packs (PR-17) are generated from **first-party events only**. Attested imports appear, if at
all, in a distinctly labeled appendix stating that the records are third-party assertions carrying
no control-effectiveness claim, together with their provenance blocks and the `HistoryImported`
event that admitted them. Exports must make it impossible for a reader to mistake an attested record
for a witnessed one.

### 7. Contracts

An additive `Provenance` message plus `HistoryImported` and `HistoryImportRevoked` audit events are
defined in `contracts/` (additive within v1 — `contracts/README.md`), so every consumer — Code
Search, evidence export, the UI — sees the classification rather than re-deriving it.

## Consequences

**Positive**
- The audit chain keeps the one property that makes it evidence: everything in it was witnessed by
  us, in our clock order. Import cannot forge history.
- PR-12 ships in full — review threads, approvals, authors, original timestamps are all preserved
  and queryable, just correctly labeled.
- The migration path is itself auditable: who imported what, from where, and whether it was later
  revoked.
- Compliance posture is defensible under questioning: an auditor asking "how do you know Alice
  approved this?" gets either a first-party chain entry or an explicit "we don't — the source system
  asserted it."
- Verified identity linking gives a graceful path from attested to attributable over time.

**Negative / costs**
- Two classes to model, store, and render; every read path touching history must handle both, and
  every new surface risks leaking one as the other.
- Imported approvals not counting toward policy means a migrated MR mid-review may need re-approval.
  Expected friction, and a support/onboarding concern.
- UI/UX work to make the distinction legible without making imported history feel second-class
  (ADR-0015 clean-UX pressure pulls against loud provenance badges).
- Manifest digests add storage and an import-time hashing step.
- Identity mapping is a new surface with its own authorization questions.

**Follow-ups**
- SPEC for repository + history import (PR-12), with acceptance criteria asserting: no imported
  record reaches the audit log; no imported approval satisfies a merge policy; evidence export
  contains zero attested records in its control sections; a tampered post-import record fails
  manifest verification.
- Contract additions: `Provenance`, `HistoryImported`, `HistoryImportRevoked`.
- Task(s) under Phase 1 for import; extend the evidence-export work (Phase 2) with the appendix rule.
- Fitness function / boundary test: the audit writer rejects any record whose provenance is not
  `FIRST_PARTY`.
- Retention: attested records inherit the tenant's repo retention, not audit retention (ADR-0007
  retention follow-up).
- Verified-identity-mapping design (may warrant its own ADR if it grows past an admin assertion).

## Alternatives considered

- **Write imported events into the audit log with their original timestamps** — rejected: backdating
  a hash-chained log breaks chain-order integrity and hands anyone with import rights a
  history-forgery primitive. Directly contradicts ADR-0007's purpose.
- **Write imported events into the audit log with import-time timestamps and a source note** —
  rejected: the chain stays intact, but the log now contains unverified assertions, so evidence
  exports must filter by a note field. One missed filter and unverifiable claims enter a SOC 2
  walkthrough. The separation belongs in the storage model, not in downstream query hygiene.
- **A second parallel hash-chained "import log"** — rejected: chaining implies a trust property the
  content does not have; two chains invite conflation, and the manifest digest already provides
  post-import integrity at far lower cost.
- **Import code and refs only; drop MR/PR history** — rejected: removes PR-12's value for the
  migrator motion, which is the ICP's most concrete trial blocker.
- **Store imported history as an opaque attachment/blob per repo** — rejected: unqueryable, not
  renderable inline in review UX, and pushes provenance handling onto every future consumer.
- **Auto-map foreign handles to platform users by email match** — rejected: email match is not proof
  of control, and a silent mapping turns a foreign assertion into an apparent platform approval —
  exactly the forgery this ADR exists to prevent.
