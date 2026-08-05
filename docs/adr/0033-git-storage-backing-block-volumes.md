# ADR-0033: Live bare repos stay on block volumes — SeaweedFS-FUSE fails git's rename contract

- **Status:** Proposed
- **Date:** 2026-08-06
- **Deciders:** platform
- **Governs:** G3 durability/correctness of the git plane
- **Relates to:** ADR-0020 (closes its open knob), ADR-0016 (confirms its assumption, no amendment),
  ADR-0023 (confirms "FUSE not for live repos"), ADR-0004 (git storage tier) ·
  **Invariants:** 7 · **Tasks:** T-0007 · **Evidence:** `../bench/T-0007/README.md`

## Context

ADR-0020 adopted SeaweedFS and left exactly one knob open: *"Repo storage backing: SeaweedFS-FUSE vs
fast block volumes. Default recommendation: block volumes for live repos, SeaweedFS-S3 for blobs.
Decide (and possibly amend ADR-0016) once benchmarked."* It named the risk correctly — git is
sensitive to "many small-file ops, locks, atomic renames, fsync" — but recorded it as a
**recommendation without evidence**. Invariant 7 has been carrying that recommendation as a rule
*"unless the benchmark follow-up in ADR-0020 concludes otherwise"*, and ADR-0016's sync-replica design
assumes local block volumes. So a rule, an invariant and a failover design have all been resting on an
unmeasured assumption, which T-0007 existed to either confirm or overturn.

T-0007 measured both arms on one physical disk (so the delta isolates the storage path, not the
device), with SeaweedFS 4.40 and git 2.54. Full numbers, environment and limits:
[`../bench/T-0007/README.md`](../bench/T-0007/README.md); raw JSON beside it.

**Performance** would not have settled anything on its own. FUSE costs ~12% on bulk push and clone,
~2× on `gc` and `status`, and 2.6× on concurrent push throughput. That is a recognisable shape — one
big sequential packfile write is fine, thousands of small metadata operations are not — and it is the
kind of cost a project can choose to pay.

**Correctness did settle it.** Git commits every ref update by renaming `refs/heads/<name>.lock` over
`refs/heads/<name>`. On the FUSE arm, **36 of 428** concurrent `git rev-parse --verify` calls failed to
resolve a ref that never stopped existing; on block, 0 of 229. Two properties of that result matter
more than its size:

- **It is not the measuring tool.** The first probe used `mv(1)`, which on `EXDEV` degrades to
  copy+unlink and manufactures exactly such a window. Rewritten to use `git update-ref` — which calls
  `rename(2)` directly and reports failure — **`writer_errors` was 0**: every rename succeeded. Rename
  works on this backend; it is not atomic.
- **It reproduced three times** across two independent probe designs, with the block arm at exactly
  zero every time.

Everything else passed on FUSE: `O_CREAT|O_EXCL` yields a single winner, fsync survives a remount,
contended pushes resolve to one winner, `git fsck` is clean. The backend is not broadly broken — it
misses one guarantee that git requires on every single ref write.

## Decision

We will **keep live bare git repositories on fast block volumes** and **not** use SeaweedFS-FUSE for
them, now on measured grounds rather than as a precaution.

1. **ADR-0020's knob is closed** in favour of block volumes. The follow-up it recorded is discharged.
2. **ADR-0016 is not amended.** Its sync-replica + failover design assumed local block volumes, and
   that assumption is confirmed rather than overturned — the amendment ADR-0020 anticipated is not
   needed.
3. **Invariant 7 stands as written.** Its escape clause ("unless the benchmark follow-up in ADR-0020
   concludes otherwise") is now spent: the benchmark concluded the same way the rule already read.
4. **SeaweedFS keeps its role** — S3 for LFS objects, artifacts and registry blobs, where content is
   written once, addressed by key, and never subject to a rename race. Nothing here argues against
   SeaweedFS as an object store; ADR-0023's "FUSE not for live repos" is confirmed.
5. **The disqualifier is recorded as a property, not a benchmark score**, so a future proposal to
   revisit this must clear a specific bar: demonstrate atomic `rename()` over an existing path under
   concurrent readers. A faster FUSE client does not reopen the question.

## Consequences

**Positive:** the git plane's most load-bearing filesystem assumption is now backed by a reproducible
experiment (`make bench-storage`) rather than by caution, and the failure mode is named precisely
enough to re-test in one command. ADR-0016 needs no rework. The harness generalises — it takes a
directory, so any future candidate backend (a different CSI driver, NFS, a tuned FUSE client) can be
put through the same probes before it is trusted.

**Negative / costs:** block volumes are less elastic and usually costlier per GB than object storage,
and under BYO they are one more per-cloud primitive to require of a customer's cluster (G8). Capacity
planning for repo storage stays a real operational task instead of being absorbed by an object store.
We also carry two storage technologies in the data plane rather than one.

**Follow-ups:**
- The numbers behind this decision come from **one workstation with a single-node filer**. The
  correctness verdict is hardware-independent and needs no re-run; the *latency ratios* should be
  re-measured on the real cluster once T-0003 is verified, and this ADR superseded only if a cluster
  run contradicts the correctness result — which it cannot, absent a change in the FUSE client.
- The harness only probes what git needs today. If the storage tier later grows a second writer
  (a mirroring daemon, a background repacker), `flock`/`fcntl` semantics deserve a probe too; they are
  untested here and not claimed either way.

## Alternatives considered

- **Adopt SeaweedFS-FUSE for live repos** — rejected on the rename result, not on speed. A ref read
  that transiently reports "no such branch" is a wrong answer served to a user during ordinary
  concurrent traffic, and there is no tuning knob that makes a non-atomic rename atomic.
- **Use FUSE and work around it in application code** (retry ref reads, serialise all ref writes
  through one process) — rejected: it would mean re-implementing part of git's ref transaction layer
  on top of a filesystem that breaks its contract, in the one component where being wrong is
  unrecoverable. It also concedes the sync-replica design in ADR-0016.
- **Defer the decision until a cluster run** — rejected: the correctness finding does not depend on
  the cluster, and leaving invariant 7's escape clause open invites someone to read the
  recommendation as still-undecided. The cluster run remains worth doing for the ratios, which is
  recorded as a follow-up rather than as a blocker.
- **Amend ADR-0016 to be storage-agnostic** — rejected as scope: nothing measured here asks for a
  change to the failover design, and an ADR that widens a decision it did not test is how unmeasured
  assumptions get introduced in the first place.
