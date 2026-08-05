# T-0007 — Git on SeaweedFS-FUSE vs block volumes: results

Raw output of `scripts/bench-storage.sh` (super-repo) plus the reading of it. The **Proposed ADR** this
feeds is [ADR-0033](../../adr/0033-git-storage-backing-block-volumes.md); this file is the evidence,
not the decision.

## What was being settled

ADR-0020 left one knob open — *"Repo storage backing: SeaweedFS-FUSE vs fast block volumes. Decide
(and possibly amend ADR-0016) once benchmarked."* — and named the risk precisely: git is sensitive to
"many small-file ops, locks, atomic renames, fsync". Invariant 7 already assumes block volumes
*"unless the benchmark follow-up in ADR-0020 concludes otherwise"*. So this benchmark either confirms
an assumption with evidence or overturns it.

## Environment — read before quoting a number

| | |
|---|---|
| Host | one Linux workstation, kernel 7.1.5, rootless podman |
| Both arms | the **same** physical disk (btrfs), so the delta isolates the storage *path*, not the device |
| Block arm | host directory bind-mounted into the container |
| FUSE arm | `weed server -filer` + `weed mount`, single node, volume store on that same disk |
| Versions | SeaweedFS 4.40 (pinned in `deploy/dev/versions.env`), git 2.54.0 |
| Params | `--repeats 3 --concurrency 4 --size-mb 8`; fixture 24 files × 341 KB over 8 commits, ~27 MB `.git` |

**Absolute latencies are directional only.** A workstation with a single-node filer is not a cluster:
no pod-to-pod network, no multi-node replication, no cloud block-volume characteristics. What
transfers is the *ratio* between two arms measured on one disk, and — with no caveat at all — the
correctness verdicts, because O_EXCL atomicity, `rename()` atomicity and fsync durability are
properties of the filesystem implementation rather than of the hardware under it.

## Latency and throughput (run of 2026-08-06, 3 samples each)

| Operation | block | SeaweedFS-FUSE | FUSE / block |
|---|---|---|---|
| push (mean) | 3934 ms | 4391 ms | **1.12×** |
| clone | 80.6 ms | 89.9 ms | **1.12×** |
| gc | 158.8 ms | 329.2 ms | **2.07×** |
| status | 25.5 ms | 51.1 ms | **2.00×** |
| push throughput | 10.01 MiB/s | 8.90 MiB/s | 0.89× |
| concurrent push (4 workers) | 238 ops/s | 91 ops/s | **0.38×** |

The shape matters more than the magnitudes: **bulk streaming costs ~12%, per-file metadata work costs
~2×, and concurrent push throughput drops 2.6×.** That is what a chunked object store behind a FUSE
client would be expected to do — packfile transfer is one big sequential write, while `gc`, `status`
and ref updates are thousands of small metadata operations.

Perf alone would be an engineering trade, not a disqualification. The next section is the
disqualification.

## Correctness

| Probe | block | SeaweedFS-FUSE |
|---|---|---|
| `O_CREAT\|O_EXCL` single winner (4 racers) | ✅ 1 winner | ✅ 1 winner |
| `rename()` atomic under concurrent reader | ✅ 0/200 anomalies | ❌ **15/200 reads found no file** |
| fsync then read back | ✅ | ✅ |
| durable across a remount | n/a | ✅ **true** |
| contended push to one ref | ✅ 1 accepted, 3 rejected | ✅ 1 accepted, 3 rejected |
| `git fsck` after contention | ✅ exit 0 | ✅ exit 0 |
| **git's own `update-ref` / `rev-parse` race** | ✅ 0 misses / 229 reads | ❌ **36 misses / 428 reads (8.4%)**, 0 writer errors |

### The finding

**`rename()` is not atomic on the SeaweedFS FUSE client, and git's ref update depends on it being
atomic.**

Git commits every ref update by writing `refs/heads/<name>.lock` and renaming it over
`refs/heads/<name>`. On the FUSE arm, 36 of 428 concurrent `git rev-parse --verify refs/heads/race`
calls failed to resolve a ref **that never stopped existing** — the reader landed in a window where
the target was absent. On block, 229 reads, zero misses.

Two things make this a verdict rather than a curiosity:

1. **It is not an artifact of the measuring tool.** The first version of this probe used `mv(1)`,
   which has a loophole: on `EXDEV`, coreutils `mv` degrades to copy+unlink and *manufactures* exactly
   this window. So the probe was rewritten to use `git update-ref`, which calls `rename(2)` directly
   and reports failure. **`writer_errors` is 0** — git's renames all succeeded — while readers still
   missed the ref. Rename works; it is simply not atomic.
2. **It reproduced three times**, across two independent probe designs: the `mv` proxy found 15 and 11
   anomalies in two runs, the git-native probe found 36 misses, and the block arm was exactly 0 every
   time under identical conditions.

What it costs in production: any concurrent reader of a ref — a `fetch`, a push's fast-forward check,
`upload-pack`'s ref advertisement during clone — can conclude a branch does not exist while it does.
That is a wrong answer served to a user, not a slow one, and no amount of tuning changes a
non-atomic rename into an atomic one.

Note what did **not** fail: O_EXCL locking is sound, fsync survives a remount, contended pushes
resolve to exactly one winner, and `fsck` is clean afterwards. FUSE is not broadly broken — it fails
on one specific guarantee that git happens to require for every single ref write.

## Reproducing

```
make bench-storage                     # defaults: 3 repeats, 4 workers, 24 MiB fixture
./scripts/bench-storage.sh --keep      # keep the container to inspect weed logs
```

Needs podman and `/dev/fuse`. The driver refuses to run if the scratch directory is tmpfs, because
comparing a "block volume" against RAM would flatter the wrong arm.

## Honest limits of this run

- **One host, one disk, single-node filer.** Cluster numbers will differ; the ratios and the
  correctness verdicts are what carry over.
- **`concurrency 4`** is a small race. The rename window is a probability, not a constant — the miss
  *rate* is not a stable figure to quote, but non-zero versus exactly zero is the signal.
- **Default mount options.** A different `weed mount` tuning may move the latency numbers. It cannot
  make a non-atomic rename atomic, which is why the perf table is the negotiable part and the
  correctness table is not.
- **`gc` is plain `git gc`,** not `--aggressive`. An earlier run used `--aggressive` and spent ~100 s
  recomputing deltas over incompressible fixture data, swamping the storage signal.
