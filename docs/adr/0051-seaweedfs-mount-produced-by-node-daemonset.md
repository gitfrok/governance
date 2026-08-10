# ADR-0051: The SeaweedFS FUSE mount is produced by one privileged node DaemonSet, not by a sidecar in each pod

- **Status:** Proposed
- **Date:** 2026-08-11
- **Deciders:** platform
- **Governs:** G9 least-privilege footprint, G4 durability, G3 supply chain
- **Refines:** ADR-0050 (large objects over a SeaweedFS FUSE mount — this decides *how the mount is
  produced*, which ADR-0050 left open)
- **Relates to:** ADR-0035 (first-party image posture — **unchanged**), ADR-0024 (Minikube-only local
  dev), ADR-0033 (live repositories stay on block volumes — **unchanged**), ADR-0020 (SeaweedFS)
- **Invariants:** 7 · **Tasks:** T-0003, T-0018

## Context

ADR-0050 decided that large objects are read and written through a SeaweedFS FUSE mount "presented to
the data plane as a filesystem path". It did not say how that path comes to exist on a Kubernetes
node, and the answer is not free: **every way of producing a FUSE mount in Kubernetes requires a
privileged container somewhere.**

The constraint is kubelet's, not SeaweedFS's. A mount made inside a container is visible only in that
container's mount namespace unless the volume carrying it is declared `mountPropagation:
Bidirectional`, and kubelet **rejects `Bidirectional` on any container that is not privileged**. So a
`weed mount` sidecar running unprivileged beside `git-storaged` would appear to succeed, and the
application container next to it would see an empty directory.

That empty directory is the specific danger. `objectstore.NewMount` refuses to create its root
precisely because a mount point the process had to create is a mount point that was not mounted — but
it cannot distinguish a directory that exists *because someone mounted a filer over it* from one that
exists because a `hostPath` volume with `DirectoryOrCreate` made it. Objects written into the second
are on one node's local disk, invisible to every other node, and indistinguishable from success until
another node looks for them.

So the question is not *whether* to grant privilege. It is **where the privilege sits, how many
copies of it exist, and what happens when the mount is absent.**

## Decision

1. **One privileged DaemonSet per node produces the mount.** A workload named `seaweedfs-mount` runs
   `weed mount` against the filer, mounts onto a `hostPath` with `mountPropagation: Bidirectional`,
   and is the only privileged workload in the deployment.
2. **Application pods stay exactly as hardened as they are today.** `git-storaged` and the data plane
   consume the mount through a `hostPath` volume with `mountPropagation: HostToContainer`. They keep
   `runAsNonRoot`, `allowPrivilegeEscalation: false` and `capabilities: drop: ["ALL"]`. ADR-0035's
   posture is untouched, and no first-party image gains a capability.
3. **A pod that cannot see a live mount refuses to start.** Each consumer runs an init container that
   blocks until the path is a FUSE mount in its own mount table, and fails rather than proceeding.
   Without this, the failure mode is not a crash but silent divergence: an empty `hostPath` accepts
   writes and reports success.
4. **The privileged workload is third-party, not first-party.** It is the SeaweedFS image already
   pinned in `versions.env`. Nothing this platform builds gains privilege, which keeps the blast
   radius inside a component whose supply chain ADR-0034 already governs.
5. **This is the dev-cluster mechanism.** A production cluster should reach the same filesystem
   through the SeaweedFS CSI driver, where the privileged node plugin is the driver's rather than
   ours. That is a separate decision with its own pin and its own failure modes, and it is not made
   here.

## Consequences

**Positive**
- Privilege exists in exactly one workload per node instead of one per pod that touches large
  objects — the count stops growing as consumers are added (LFS today; CI artifacts and registry
  blobs are already named by ADR-0050).
- The consumers' security contexts do not change, so the posture test that guards them keeps passing
  and keeps meaning what it did.
- An absent mount becomes a pod that will not start, which is loud. The alternative was a pod that
  writes to node-local disk and reports success.

**Negative — and the one to weigh hardest**
- **A privileged container with `/dev/fuse` and `SYS_ADMIN` can escape to the node.** That is the
  real cost, and concentrating it does not remove it. It is accepted here for a dev cluster and
  should not be carried into production unexamined — decision 5 is the intended exit, not a
  formality.
- **The mount is a per-node dependency with a new failure mode:** the DaemonSet dying takes LFS down
  on that node, and — by decision 3 — takes its consumers with it on the next restart. ADR-0050
  already recorded the per-node dependency; this makes it a scheduling dependency too.
- `hostPath` pins the consumers to nodes where the DaemonSet has run, which is every node, but it is
  still a coupling that a CSI driver would not have.

**Follow-ups**
- Evaluate the SeaweedFS CSI driver as the production mechanism, and record whether it replaces this
  or coexists.
- The smoke test asserts Deployments only; it needs to assert this DaemonSet, or a broken mount is
  green.

## Alternatives considered

- **A privileged `weed mount` sidecar in each consumer pod.** Rejected: it puts privilege inside the
  same pod as the application, multiplies it by the number of consumers, and would force
  `git-storaged` — which already runs the one first-party image with a writable root filesystem — to
  also host a privileged neighbour.
- **Mount on the host outside Kubernetes** (`minikube ssh`, or a systemd unit on a real node).
  Rejected: it moves a required step out of the manifests into an operator's memory, and
  `deploy/dev/` exists so that bringing the stack up is one command that converges.
- **The SeaweedFS CSI driver now.** Preferred eventually and deferred: it is a new third-party
  dependency needing its own ADR-0034 pin and resolvability proof, and its node plugin is privileged
  too — so it changes who owns the privilege, not whether it exists.
- **Keep S3 in the dev cluster and use the mount only in production.** Legitimate — ADR-0050
  decision 6 keeps the S3 adapter exactly so a deployment without a mount can run. Rejected because
  it leaves the mount path unexercised everywhere it is cheap to exercise, which is how the
  difference between the two adapters gets discovered in production.
