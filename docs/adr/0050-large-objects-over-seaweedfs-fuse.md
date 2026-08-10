# ADR-0050: Large objects (LFS, CI artifacts, container images) are served from a SeaweedFS FUSE mount

- **Status:** Accepted
- **Date:** 2026-08-11 (proposed and accepted the same day)
- **Deciders:** platform
- **Governs:** G3 supply chain, G4 durability, G8 cost governance
- **Relates to:** ADR-0020 (SeaweedFS-S3 for blobs — this narrows it), ADR-0033 (live repos on block
  volumes — **unchanged**), ADR-0004 (git storage tier), ADR-0023 ("FUSE not for live repos" —
  unchanged), SPEC-0023 (Git LFS transport, Approved 2026-08-10) ·
  **Invariants:** 7 · **Tasks:** T-0018, T-0010

## Context

ADR-0020 chose SeaweedFS and said **S3** for LFS, CI artifacts and registry blobs. SPEC-0023 was
approved on that basis and is implemented: the platform speaks S3 to a SeaweedFS gateway and hands
clients short, per-object, per-method pre-signed URLs so object bytes never cross the application
path.

The direction now is to reach those objects through a **SeaweedFS FUSE mount** instead of the S3
API — for LFS objects, CI artifacts and container-image blobs alike.

This is a decision, not an implementation detail, for two reasons. It contradicts ADR-0020's stated
posture and ADR-0033 §4 ("SeaweedFS keeps its role — S3 for LFS objects, artifacts and registry
blobs"), and it changes the data path SPEC-0023's transfer decision rests on. It must be recorded
before code moves, which is why this ADR exists rather than a patch.

**What it does not touch.** Live bare git repositories stay on block volumes. ADR-0033 settled that
on measurement — 36 of 428 concurrent ref reads failed on the FUSE arm, 0 of 229 on block, because
git renames `refs/heads/<name>.lock` over the ref on every write and that rename is not atomic on
this backend. Nothing here reopens it, and `git-storaged` keeps refusing a FUSE repository root
(`ErrFUSERepositoryRoot`, invariant 7).

**Why large objects are a different case.** The ADR-0033 failure needs a name that already exists and
a reader racing a writer over it. Large objects are content-addressed and write-once: an object's
name is its digest, so no writer ever replaces content another reader is holding, and a second write
of the same OID is byte-identical to the first. The property git needs and SeaweedFS-FUSE lacks is
one the object path does not depend on.

## Decision

Large objects — **Git LFS objects, CI artifacts, and container-image blobs** — are read and written
through a **SeaweedFS FUSE mount** presented to the data plane as a filesystem path.

1. **The object tier becomes a mount, not an endpoint.** The platform is configured with a mount
   path instead of an S3 gateway URL, credentials and region. The `ObjectStore` port already in the
   tree does not change shape; a mount-backed adapter joins the S3-backed one.
2. **Writes are staged and committed by rename inside the mount.** An object is written to a
   temporary name in the same directory, fsynced, and renamed onto its content-addressed final name.
   Rename on this backend is *not atomic* (ADR-0033), so the final name may briefly resolve
   inconsistently to a concurrent reader — see the consequence below, which is the load-bearing one.
3. **Readers verify.** Every read of an object verifies the content against the digest in its name
   before the bytes are handed to a client. This is what makes a torn rename detectable rather than
   silently served. An object that fails verification is treated as absent, and the read is retried
   or refused — never returned.
4. **Transfers proxy.** SPEC-0023's pre-signed-URL decision does not survive this change: a mount has
   no signed URLs. Object bytes flow through the data plane, which authorizes each transfer per
   object under the existing `repo.lfs.read`/`repo.lfs.write` actions. The revocation window that
   pre-signed URLs traded away is regained; the plane's egress and CPU pay for it.
5. **Tenant scoping is unchanged.** The key layout — tenant first, then the digest — becomes the
   directory layout. The same OID in two tenants remains two objects.
6. **ADR-0020's S3 posture is narrowed, not deleted.** The S3 adapter stays in the tree and stays
   tested: it is how a deployment without a mount runs, and it is the reference the FUSE adapter's
   behaviour is compared against.

## Consequences

**Positive**
- One filesystem for every large-object consumer: LFS, CI artifacts and the registry stop each
  needing their own S3 credential path.
- No pre-signed credential leaves the platform, so no unrevokable capability exists — the concern
  SPEC-0023 recorded and accepted is removed rather than mitigated.
- Simpler local and air-gapped operation: a mount is inspectable with ordinary tools.

**Negative — and the one to weigh hardest**
- **Every object byte now crosses the data plane.** That is the cost SPEC-0023's decision 1 was
  chosen to avoid; a large `git lfs pull` is now the plane's egress and CPU, and it must be paced
  against interactive git the way import work is.
- **Non-atomic rename is now on the object write path.** It is survivable only because reads verify
  digests (§3). Without that verification this decision is unsafe, and any future change that
  removes verification for performance re-introduces a torn-object read.
- FUSE's metadata cost applies to object listing and existence checks — the `Stat` an import does per
  object before deciding whether to fetch it.
- The mount is a per-node dependency: a node whose mount is unavailable cannot serve LFS, where
  previously it could reach the gateway over the network.

**Follow-ups**
- Amend SPEC-0023: replace the pre-signed transfer decision with proxied transfer, and add the
  read-verification criterion as an acceptance criterion rather than a note.
- Benchmark object read/write on the mount against the S3 path, the way T-0007 benchmarked repos, so
  the egress cost above is a number rather than an expectation.
- Decide whether the registry's blob path can share this adapter or needs its own (out of scope
  here).

## Alternatives considered

- **Keep S3 for everything (status quo, ADR-0020).** Keeps bytes off the plane and keeps signed,
  scoped, expiring capabilities. Rejected by this decision, but it remains the implemented and
  tested path.
- **FUSE for writes, S3 for reads.** Would keep egress off the plane while giving writers a plain
  filesystem. Rejected: two paths to the same bytes doubles the failure modes and makes the
  digest-verification rule easy to apply on one side only.
- **FUSE for live repos as well.** Refused on measured grounds (ADR-0033). Nothing in this ADR
  disturbs it.
