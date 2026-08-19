# SPEC-0056: Releases — a tag, some notes, and an honest answer when the tag moves

- **Status:** Approved (2026-08-19) — ADR-0075 Accepted with this increment; RED may begin
- **Owner:** platform
- **Context(s):** Release (new, owns the release record) · Repository/Git (serves the tags) · BFF ·
  Web frontend — ADR-0022
- **ADRs:** 0075 (decides this and its scope), 0071 (the registry-as-truth shape this reuses), 0062
  (durability), 0070, 0022, 0069, 0006, 0007
- **Task(s):** T-0064 (backend), T-0065 (contract + bff), T-0066 (web)

## Problem / context

PR-29 asks that a team can cut and publish a release from a tag, with its artifacts and notes.
ADR-0075 accepted the **first increment only: tags and notes, no artifacts** — because the moment a
customer's users download an artifact from this platform it is in their supply chain, and the
signing, custody, retention and metering that implies is a larger decision than the feature looks.

So this spec builds a release as **a name for a commit, plus prose about it**. That is a coherent
and genuinely useful product: it is what a changelog is.

**The honesty rule on this surface is the moved tag, and it is the reason a release is a record
rather than a view.** A tag is a mutable pointer. It can be moved, deleted, or recreated against a
different commit, and git will not remark on it. If a release were merely a rendering of "whatever
`v1.2.0` means today", then republishing that tag against a different commit would silently rewrite
history for every reader — the release notes would still describe the old commit while the page
showed the new one.

This is the same shape ADR-0071 fixed for repositories: **the record is the truth, not the disk.** A
release records the commit its tag pointed at *when it was published*, and the surface says so when
the two have since diverged.

## In scope

- Listing a repository's tags, with the commit each points at.
- Publishing a release against a tag, with notes, recording who and when.
- Listing and reading a repository's releases.
- Editing a release's notes, recording when they were last edited.
- The moved-tag and deleted-tag renderings.

## Out of scope

- **Artifacts**, by ADR-0075's accepted scope. Not a field, not an upload, not a link, and not a
  "coming soon" — each re-opens signing, custody, retention and metering at once.
- Signing, verification, or any statement about provenance beyond the recorded commit.
- Creating, moving or deleting a tag. Tags are made by `git push`; this surface reads them.
- Pre-releases, draft states and release channels. Each is a lifecycle, and a lifecycle is a
  decision.
- Deleting a release. Archival and deletion are ADR-0076's territory and unresolved there too.

## Contracts touched

- `contracts/proto/repository/v1` — **additive**: `ListTags` on `RepositoryReader`, which serves it
  from the bare repository as it serves tree and history.
- `contracts/proto/release/v1` — **new package**: `ReleaseService` with `PublishRelease`,
  `GetRelease`, `ListReleases`, `UpdateReleaseNotes`.

## Data owned

The Release context owns a tenant-scoped `release.releases` table: tenant, repository, tag,
`published_commit`, notes, publisher, published-at, notes-updated-at. Module-owned migration, RLS on
`tenant_id`.

## Acceptance criteria (each becomes a test)

### The backend (T-0064)

- [ ] **AC1** `ListTags` returns a repository's tags with the commit each points at, newest-first by
      tag creation where git reports it, paged by an opaque cursor. It is a `repo.read` decision
      through the same `prepareRead` every other read on that surface uses.
- [ ] **AC2** Publishing records the tag, **the commit that tag points at now**, the notes, the
      publisher and the instant. The commit is resolved server-side at publish time; a caller cannot
      assert it, and there is no field for one.
- [ ] **AC3** A release is unique per (tenant, repository, tag). Publishing the same tag twice is
      refused rather than silently creating a second release — two releases of `v1.2.0` is not a
      state this product has an answer for.
- [ ] **AC4** Notes can be updated, and the record carries when they last were. The tag and the
      published commit **cannot** be updated: correcting prose is editing documentation, changing
      what a release points at is publishing a different release.
- [ ] **AC5** The release survives a process restart; the table is tenant-scoped with RLS and its
      migration passes T-0004's boundary linter; a cross-tenant release is absent rather than
      forbidden.
- [ ] **AC6** **The store never resolves the tag on read.** `GetRelease` and `ListReleases` return
      the commit recorded at publish time, and nothing in the Release context asks git what the tag
      means now. Comparing them is the reader's surface's job (AC11), and doing it here would make
      this context depend on Repository/Git, which ADR-0022 forbids.
- [ ] **AC7** **The isolation proofs ran.** Zero skips for the tenancy cases; the exit record states
      the observed skip count (carried limit 5).

### The wire and the BFF (T-0065)

- [ ] **AC8** Additive: `buf breaking` passes; `release/v1` is a new package and `ListTags` is a new
      RPC, so nothing existing moves.
- [ ] **AC9** **No message in `release/v1` carries an artifact.** A descriptor test asserts no field
      named `artifact`, `artifacts`, `asset`, `assets`, `download_url` or `attachment` — ADR-0075's
      accepted scope as a type property, so the increment cannot grow past its decision quietly.
- [ ] **AC10** The BFF shapes and forwards under the session; every failure is one coarse refusal;
      the publisher's identity comes from the session and has no field on the request.

### The view (T-0066)

- [ ] **AC11** **A release whose tag has moved says so.** The page compares the recorded commit with
      the tag's current target and renders three distinct states: the tag still points there; the
      tag now points elsewhere; the tag no longer exists. A test drives all three.
- [ ] **AC12** **The absence of artifacts is stated, not implied.** The surface says releases here
      are a tag and notes and that no files are stored, and the copy enumeration forbids "coming
      soon", "no artifacts yet" and any phrasing implying an upload is pending or permitted.
- [ ] **AC13** Publishing is a plain form against a tag chosen from the listed tags; editing notes
      is a plain form; both work with no client script.
- [ ] **AC14** Notes render as text, not as HTML. A release note containing markup is displayed, not
      executed — this is the product's first surface storing free-form prose, and it is not going to
      be the one that learns about injection.
- [ ] **AC15** No hex literal; units on every length; a refusal names no cause; the two regression
      pins unmodified.
- [ ] **AC16** The stub serves tags and releases including a moved-tag and a missing-tag fixture;
      captures regenerated per SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | RLS on the new table; a cross-tenant release is absent, not refused with a reason. |
| G2 authorization | Publishing and reading are PDP decisions on the repository; this context adds no permission of its own. |
| G5 auditability | A release records who published it and when, and when its notes last changed. The moved-tag rendering is the auditability criterion in practice: it stops a release from silently describing a commit it no longer names. |

## Non-functional

- Notes are bounded — a release note is prose, not a document store, and the bound is enforced at
  the contract and the column.

## Open questions / assumptions

1. **Notes are mutable and the tag is not.** ADR-0075's immutability question returns with
   artifacts; for prose, refusing to fix a typo helps nobody.
2. **No ordering guarantee across repositories.** Releases are listed per repository, which is how
   they are read.
3. **A release of a deleted tag is kept, not hidden.** It happened, it was announced, and hiding it
   would make the record less true than the world.
