# SPEC-0023: Git LFS transport and object store

- **Status:** Implemented (2026-08-11) — every acceptance criterion is proven by its task(s); approved (spec review 2026-08-10; **amended 2026-08-11 for ADR-0050** — the object tier
  is a SeaweedFS FUSE mount and transfers proxy, superseding the pre-signed decision below)
- **Owner:** unassigned
- **Context(s):** Repository/Git (git-storaged, transport), with objects on the SeaweedFS-S3 tier
- **ADRs:** 0004 (git storage tier — large objects on SeaweedFS-S3), 0033 (repos on block volumes,
  SeaweedFS keeps the S3 role), 0020 (SeaweedFS-S3 in the stack), 0016 (durability), 0006 (PDP),
  0003 (tenancy), 0007 (audit)
- **Task(s):** T-0010 (SPEC-0004 AC2 — the unchecked half), T-0018 (AC2 depends on this)

## Problem / context
The platform has no Git LFS support of any kind. Nothing in the tree resolves an LFS pointer,
speaks the LFS batch API, or writes an object to S3 — `grep -ri lfs` over `backend/` returns
nothing outside comments. The ADRs settled **where** large objects live (SeaweedFS-S3, ADR-0004 §
ADR-0033 decision 4) and `SPEC-0004` AC2 restates it, but no spec says **how** the platform serves
LFS: what protocol endpoints exist, how an object is authorized per tenant, how a pointer is
resolved on read, or what durability an upload is acknowledged under.

This blocks two criteria that are currently unmet for the same missing reason:

- `SPEC-0004` AC2 (LFS/artifacts use SeaweedFS-S3) — half of it is unimplemented.
- `SPEC-0011` AC2 / T-0018 AC2 (an import's LFS pointers resolve and the referenced objects are
  fetchable afterwards). `git fetch` moves **no** LFS object, so an import today lands pointers
  whose objects do not exist. That is worse than refusing the import: the repository looks complete
  and its large files are missing.

T-0018 stopped rather than inventing this design mid-implementation, which is why this spec exists
before the code does.

## In scope
- The **Git LFS batch API** (`POST /{repo}.git/info/lfs/objects/batch`) for `upload` and `download`,
  and the object transfer endpoints those operations point at, served by the Git front door that
  already terminates Smart-HTTP.
- **Object storage on SeaweedFS-S3, and only there.** SeaweedFS is the object store (ADR-0020,
  ADR-0033 decision 4), not one S3-compatible option among several: the platform is configured with
  a SeaweedFS gateway address, its variables name SeaweedFS, and there is no credential chain, no
  region resolution, and no fallback that could put objects anywhere else. Keys are laid out so no
  two tenants can name the same object, and so a key discloses nothing about another tenant.
- **Authorization** of every LFS operation through the PDP, as its own action vocabulary
  (`repo.lfs.read`, `repo.lfs.write`) rather than by reusing `repo.read`/`repo.write` — a large-file
  read is a distinct, expensive permission and should be grantable and deniable on its own.
- **Import path**: resolving the pointers a fetched repository carries, fetching each referenced
  object from the source's LFS endpoint with the import's request-only token, and writing it to this
  platform's object store as part of the import's git phase.
- **Accounting**: the bytes an LFS upload or import writes are reported by the tier that wrote them,
  the same seam `SPEC-0011` AC21 already defines (`StorageMeter`).

## Out of scope
- CI artifacts and registry blobs. They share the SeaweedFS-S3 tier by ADR-0020 but not this
  protocol; they get their own spec.
- LFS **locking** (`/locks` endpoints). Deferred deliberately: it is a collaboration feature, not a
  storage one, and nothing in Phase 1 requires it.
- Deduplication or garbage collection of unreferenced objects. Both need a decision about when an
  object stops being referenced, which is its own ADR.
- Transfer adapters other than `basic` (no `multipart`, no custom adapters).

## Contracts touched
- `contracts/proto/git/v1/git.proto` — additive: an LFS object port on `GitStorage` so the front
  door does not talk to S3 itself (invariant: the front door authorizes and forwards; storage owns
  the write path).
- `contracts/proto/repository/v1/repository.proto` — additive, read side: whether a path's content is
  an LFS pointer, so the browser view can say so instead of rendering the pointer text as the file.
- `contracts/events/repository/v1/events.proto` — additive: an event for an accepted object write, in
  the same shape as `RefUpdated`.
- `policies/gitsaas/authz/authz.rego` — the `repo.lfs.*` actions and their resource kind.

Nothing here is a breaking change; all of it is additive within v1.

## Data owned
Repository/Git. Pointer→object metadata lives in the Repository context's own schema, tenant-scoped
under RLS (ADR-0003); object bytes live on the SeaweedFS-S3 tier under a tenant-scoped key prefix.
No other context reads either.

## Acceptance criteria (each becomes a test)
- [ ] AC1: A `git lfs push` to a repository stores the object and returns a batch response whose
      `upload` action the client can complete; a subsequent `git lfs pull` in a fresh clone returns
      the object with a digest equal to the OID the pointer names.
- [ ] AC2: An object is acknowledged only once it is durable on the object tier. A write that cannot
      be confirmed is refused; the client is never told an object was stored when it was not
      (ADR-0016 applied to the S3 tier).
- [ ] AC3: Every LFS operation is PDP-authorized under its own action (`repo.lfs.read` /
      `repo.lfs.write`). A subject that may read a repository but holds no LFS grant is denied, and
      the denial is audited.
- [ ] AC4: Object keys are tenant-scoped. A caller in tenant A cannot fetch an object written by
      tenant B by any means available at the protocol surface, including guessing the OID: the same
      OID in two tenants is two objects.
- [ ] AC5: An OID mismatch is refused on write. The bytes a client sends are hashed on receipt, and
      an object whose content does not match the OID it was announced under is rejected rather than
      stored under a name that lies about it.
- [ ] AC6: An import resolves the pointers in the fetched repository, fetches each referenced object
      from the source's LFS endpoint using the import's request-only token, and stores it — so
      `SPEC-0011` AC2 holds: after an import, every pointer's object is fetchable.
- [ ] AC7: An import whose LFS objects cannot all be fetched does **not** report success. The import
      fails or stalls per `SPEC-0011`'s state machine; a repository is never left with pointers whose
      objects are absent while the import reads COMPLETE.
- [ ] AC8: The source's LFS credentials never appear in the audit log, an event, a job log, or the
      agent stream (`SPEC-0011` AC17 extended to the LFS fetch).
- [ ] AC9: The bytes an LFS write stores are reported by the storage tier that wrote them and handed
      to the `StorageMeter` seam, for both an ordinary push and an import.
- [ ] AC10: A browser file view of a path whose content is an LFS pointer says so, with the object's
      size, rather than rendering the pointer file's text as the file's content.

**Mount-backed tier** (added 2026-08-11 with ADR-0050. The first three restate on the mount what the
S3 path already had to satisfy; AC14 is new, and is the criterion the whole decision rests on.)
- [ ] AC11: An object written through the mount is staged under a temporary name in the same
      directory, fsynced, and renamed onto its content-addressed name. A crash mid-write leaves a
      temporary file and no object, never a short object under a name that claims to describe it.
- [ ] AC12: An object is acknowledged only once it is readable back from the mount at its final name
      and full length — the same rule AC2 states for S3, and for the same reason: a write the tier
      accepted is not yet a write the tier has.
- [ ] AC13: Objects remain tenant-scoped as directories: the same OID under two tenants is two files,
      and no traversal in an OID can escape its tenant's prefix.
- [ ] AC14: **Every read verifies content against the digest in the object's name before any byte is
      served.** Rename is not atomic on this backend (ADR-0033), so a concurrent reader can observe a
      torn result; verification is what turns that into a detected absence instead of a silently
      corrupted object served to a client. An object failing verification is treated as absent —
      never returned, never repaired in place.

## Governance mapping (G1–G9)
| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | tenant-scoped object keys and RLS-scoped pointer metadata (AC4) |
| G2 least privilege | LFS is its own PDP action, not implied by repository read/write (AC3) |
| G4 durability | an object is acknowledged only when durable on the tier (AC2) |
| G5 auditability | LFS denials are audited; credentials never reach the trail (AC3, AC8) |
| G8 cost governance | LFS bytes are measured at the tier that wrote them (AC9) |

## Why not an S3 SDK
The platform speaks S3 because that is SeaweedFS's own API — the protocol is the dialect, SeaweedFS
is the store. It does so over `net/http` with SigV4 signed in-tree rather than through a vendor SDK:
the surface is three verbs (put, read, presign), both planes ship from `scratch`, and an SDK carries
a credential chain, a region resolver, a retry policy and a plugin system aimed at a service this
platform does not use. A dependency that can discover credentials from an ambient environment is
also a dependency that can reach an endpoint nobody configured, which is the opposite of what
ADR-0020's choice is for.

## Non-functional
- A `download` batch response must not require the platform to stream the object through the
  control path when the object tier can serve it directly under a scoped, expiring credential.
  Whether it does is an implementation choice this spec leaves open, but the cost of getting it
  wrong is the whole plane's egress, so it is called out here rather than discovered.
- LFS traffic must be pace-able the way import work is (`SPEC-0011` AC21): a large `lfs pull` must
  not starve interactive git.

## Decisions taken at spec review (2026-08-10)
1. ~~**Transfers go direct to the object tier.** A batch response hands the client a pre-signed,
   scoped, expiring SeaweedFS-S3 URL; object bytes never traverse the application path.~~
   **Superseded by ADR-0050 (2026-08-11).** A FUSE mount has no signed URLs, so transfers **proxy**:
   object bytes flow through the data plane, which authorizes each one per object under
   `repo.lfs.read` / `repo.lfs.write`. What that buys and costs is stated in ADR-0050 rather than
   restated here — briefly, the unrevokable capability disappears and the plane's egress pays for it,
   so LFS traffic must be paced against interactive git the way import work is.

   The S3 path is not deleted. It stays implemented and tested as the deployment posture for a plane
   with no mount, and as the reference the mount-backed adapter is compared against.
2. **An import speaks the source's LFS batch API directly.** No shelling out to `git lfs`: the
   source token stays under the same rule `ImportRefs` already enforces — it travels in the request
   the platform makes and never into a child process's configuration — and the platform keeps
   control of what it fetches and how that work is paced (AC21's pacer applies).

## Open questions / assumptions
1. **Does an import fetch every object, or only those reachable from imported refs?** Fetching
   everything is simpler and can be enormous; fetching reachable-only is what a migrating customer
   expects but requires walking the imported history. Assumption for now: reachable from imported
   refs, because AC7 must be checkable.
2. This spec assumes the SeaweedFS-S3 gateway is reachable from the data plane in every environment
   it is expected to serve. T-0003's dev environment currently has no S3 lane; if that stays true, AC1
   is provable only in the cluster lane, exactly as `SPEC-0011` AC1 is.
