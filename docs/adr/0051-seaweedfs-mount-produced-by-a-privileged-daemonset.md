# ADR-0051: The SeaweedFS object mount is produced by a privileged per-node DaemonSet

- **Status:** Proposed
- **Date:** 2026-08-11
- **Deciders:** platform
- **Governs:** G3 supply chain, G4 durability, G6 operability
- **Relates to:** ADR-0050 (large objects over a SeaweedFS FUSE mount — this decides how that mount
  is produced), ADR-0033 (live repos on block volumes — **unchanged**), ADR-0023 ("FUSE not for live
  repos" — unchanged), ADR-0024 (Minikube dev environment), ADR-0047 (first-party image
  distribution — this deliberately does not apply) ·
  **Invariants:** 7 · **Tasks:** T-0018

## Context

ADR-0050 decided that LFS objects, CI artifacts and container-image blobs are read and written
through a **SeaweedFS FUSE mount presented to the data plane as a filesystem path**. It did not say
what makes that path exist on a Kubernetes node, and the answer is not free: it costs a privileged
container, which is the kind of cost that has to be recorded rather than discovered in a manifest.

Two facts force the shape.

**A mount made inside a container is invisible outside it.** Mount namespaces are per-container. For
`git-storaged` and the data plane to see a mount that another container made, the volume carrying it
must declare `mountPropagation: Bidirectional` — and kubelet **rejects `Bidirectional` on any
container that is not privileged**. There is no unprivileged arrangement of this. An unprivileged
`weed mount` sidecar beside `git-storaged` starts cleanly, reports healthy, and leaves the
application container next to it looking at an empty directory.

**That failure is silent, and it is the expensive one.** A consumer that cannot see the mount does
not error. It binds the plain directory underneath the mount point and writes objects to that node's
local disk, where every subsequent read *on that node* succeeds. Nothing observes a fault: the write
returns 200, the read returns the bytes, the digest verifies. The objects are simply not in
SeaweedFS, not on any other node, and not in any backup. This is the exact divergence ADR-0050's
verification rules exist to prevent, arriving underneath them.

So the question was never whether to grant privilege. It was where the privilege sits, how many
copies of it exist, and how a deployment that cannot have it behaves.

## Decision

The mount is produced by a **privileged DaemonSet, one pod per node**, running the third-party
SeaweedFS image, and consumed read-only-in-propagation-terms by the workloads that need it.

1. **One privileged producer per node, and nothing else privileged.** A DaemonSet runs
   `weed mount` with `privileged: true` and `mountPropagation: Bidirectional` on a hostPath volume.
   `git-storaged`, the data plane, and every future large-object consumer stay unprivileged and
   non-root. The privilege is concentrated in one workload per node whose entire job is the mount,
   rather than distributed into every consumer as a sidecar.
2. **The producer runs the upstream SeaweedFS image, not a first-party one.** ADR-0047's
   first-party distribution rule does not extend here, deliberately: the privileged container should
   be code this platform does not write. It runs the **same pin as the filer** — a mount client and a
   server on different versions is a class of bug nobody would think to look for.
3. **Consumers mount `HostToContainer` on a hostPath of `type: Directory`.** Not
   `DirectoryOrCreate`. A consumer scheduled onto a node the DaemonSet has not mounted must **fail to
   start** rather than create the path itself and begin writing to node-local disk. The failure mode
   in the Context is closed by refusing to schedule, not by a runtime check.
4. **Liveness and readiness write and read through the mount.** `mountpoint -q` is not sufficient and
   asserting it is worse than asserting nothing: `weed mount` presents the mount point *before* it
   can reach the filer, so a mountpoint check reports Ready against a path that cannot serve a byte.
   The probes write a per-node file, read it back, and delete it.
5. **The mount is node-critical and terminates slowly.** `priorityClassName: system-node-critical`,
   because evicting the mount takes large-object storage down for every consumer on the node; and a
   termination grace period long enough for the FUSE mount to flush and release rather than be
   killed mid-write.
6. **The mount reaches the filer by Service name, over the filer's gRPC port, within one subtree.**
   The filer's gRPC port is derived by SeaweedFS as HTTP+10000 and is **not announced**; a Service
   that exposes only the HTTP port produces a mount client that retries indefinitely against a port
   nothing routes. Data flows through the filer (`-volumeServerAccess=filerProxy`) rather than
   directly to volume servers, which advertise pod IPs that change on reschedule. The mount is
   scoped to a single filer subtree, so it cannot reach anything else the filer holds.
7. **A deployment whose nodes cannot propagate a mount runs the S3 adapter, explicitly.** ADR-0050
   decision 6 keeps the S3 adapter as "how a deployment without a mount runs", and this is that
   deployment. The choice is made by configuration and **reported by the deployment's own checks** —
   never inferred, never a silent fallback from a mount that failed. A cluster is on one tier or the
   other and says which.
8. **Live repositories do not come near this.** ADR-0033 stands, `GITFROK_GIT_STORAGE_ROOT` stays on
   a block volume, and `git-storaged` keeps refusing a FUSE repository root (`ErrFUSERepositoryRoot`,
   invariant 7). Nothing here reopens it.

## Consequences

**Positive**
- The mount exists on every node that has consumers, without any consumer being privileged.
- The privilege is auditable: one DaemonSet, one third-party image, one reason.
- The propagation failure is converted from a silent data-divergence bug into a scheduling failure
  (§3) and a probe failure (§4).

**Negative — and the one to weigh hardest**
- **A privileged container now runs on every node.** It has the node's mount namespace. This is the
  entire cost of ADR-0050's mount, and it is why §2 keeps first-party code out of it.
- The mount is a per-node dependency with node-critical priority, so a node whose DaemonSet pod is
  unhealthy cannot serve large objects at all — ADR-0050 already recorded this; this ADR makes it
  concrete and gives it a priority class.
- Consumers now fail to schedule on nodes without the mount. That is intended, and it is still a new
  way for a rollout to stall.
- `filerProxy` access costs a hop on every object byte, on top of ADR-0050's decision that every
  object byte already crosses the data plane.

**Measured, on the dev environment (ADR-0024, podman driver, rootless):** the DaemonSet mounts
`fuse.seaweedfs`, the mount is marked `shared` inside the pod, the node's `/` is `shared`, and the
mount **never appears in the node's mount table** — 0 seaweed mounts on the node. Consumers bound the
plain directory underneath and a write from `git-storaged` landed on node-local disk, readable back
on that node, invisible to the filer. Every check passed while the data diverged, including
`mountpoint -q` and a write-then-read gate. This is why §3, §4 and §7 are decisions rather than
notes, and why the dev cluster runs the S3 adapter with the DaemonSet available behind an explicit
switch.

**Follow-ups**
- Determine which production-candidate runtimes propagate mounts as required, so §7's fallback is a
  known set rather than a discovery.
- Benchmark the `filerProxy` hop against direct volume-server access once a topology with stable
  volume-server addressing exists.

## Alternatives considered

- **An unprivileged `weed mount` sidecar per consumer pod.** Rejected on mechanism, not preference:
  kubelet rejects `Bidirectional` on unprivileged containers, so the sidecar's mount stays in its own
  namespace and the application container beside it writes to node-local disk — silently. It is the
  failure this ADR exists to prevent, in the shape most likely to be reached for.
- **A privileged sidecar per consumer pod.** Works, and multiplies the privileged surface by the
  number of consumer replicas rather than the number of nodes, while putting privilege inside pods
  that also run first-party code. Rejected.
- **A CSI driver for SeaweedFS.** The right long-term shape: it moves the privilege into a component
  Kubernetes already expects to hold it, and gives per-volume scoping. Rejected for now as a
  dependency and an operational surface disproportionate to one mount, and revisitable without
  disturbing ADR-0050.
- **Mounting on the host outside Kubernetes (systemd unit, node image).** Removes the privileged pod
  entirely and makes the mount a node property. Rejected: it puts a platform dependency outside the
  cluster's own lifecycle, where nothing in this tree provisions, upgrades or observes it.
- **Abandon the mount and keep S3 everywhere.** That is ADR-0020 and ADR-0050 decision 6, and it
  remains the implemented and tested path (§7). Rejected as the default because ADR-0050 already
  weighed it.
