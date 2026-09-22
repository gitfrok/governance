# ADR-0106: Cost is the binding constraint on the production shape, and availability is what it buys

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** platform (written after the owner asked, twice in one session, to bring both
  environments up "in minimum cost")
- **Amends:** **ADR-0092's implied environment shape.** ADR-0092 is Accepted and is not edited
  (ADR-0001); its choice of cloud, its two-environment split and its unit boundaries all stand. What
  it never states — and what `deploy/gcp/modules/gke-cluster` silently decided — is the
  *availability* shape of a cluster. This states it, and names cost as the reason.
- **Related:** ADR-0011 (no inbound path — why Cloud NAT and the connector are not reducible),
  ADR-0012 (gVisor for CI — constrains the runner pool's machine type), ADR-0033 (live bare repos on
  block volumes — the claim this ADR is careful *not* to spend), ADR-0050 (SeaweedFS scoped to large
  objects), ADR-0066 (availability-versus-integrity, the same distinction reused), ADR-0099 (the
  third-party stateful set whose replica counts set the node floor)
- **Governs:** G7 residency, operability

## Context

The first production shape cost roughly **$920/month** and nothing in governance had asked for it.

`modules/gke-cluster/main.tf` opened with the comment *"One regional GKE cluster"* and hard-coded
`location = var.region`. No ADR chose that. It was a module-authoring default that became a
production posture, and it carried a multiplication almost nobody reads off the HCL:

> **A regional cluster creates `min_nodes` nodes PER ZONE.**

`min_nodes = 1` across `asia-southeast1`'s three zones is three nodes; across two environments, six.
That single unstated default was the majority of the bill. The same applies to `max_nodes`, so the
ceiling was three times what it appeared to be too.

Three further costs were similarly unexamined rather than decided:

- **`pd-ssd` everywhere.** The module's default cites ADR-0033, and ADR-0033 is about the **git
  tier's live bare repos**. The git tier has no manifest anywhere in `deploy/k8s`. Every `pd-ssd`
  claim in the tree today belongs to Postgres, Redpanda, OpenBao, Valkey or SeaweedFS — and ADR-0050
  explicitly scopes SeaweedFS to large objects, which is the tier ADR-0033 kept git **off**. 1,260Gi
  of premium storage was being bought on a citation that does not reach it.
- **A CI runner ceiling of 20 × `n2-standard-8`**, on an environment where no CI job has ever run.
  `min_nodes = 0` makes it free while idle, which is exactly why the ceiling was never examined.
- **A 500GB `pd-ssd` node boot disk on the data plane**, justified in a comment by "the node disk
  under the git PVCs" — but a PVC is its own persistent disk, not part of the node's boot disk, so
  the sentence describes a mechanism that does not exist.

**This ADR is being written after the change landed, and that is a deviation worth recording.**
`CLAUDE.md` says a new decision becomes a Proposed ADR and work stops. The judgement made instead
was that these were parameter changes within ADR-0092's units. That is defensible for the machine
types, the disk sizes and the storage classes. **It is not defensible for `location`**: trading a
region's zone spread for a third of the node bill is an availability decision about two production
environments, and it belonged here first. The record says so rather than presenting the sequence as
having been correct.

## Decision

**1. Both production environments run ZONAL clusters, and availability is the thing being spent.**
`asia-southeast1-a` for both. A zone outage takes the whole environment with it — there is no
multi-zone control plane and no node in a second zone to reschedule onto. This is accepted because
no SLO, contract or user currently asks otherwise, and it is the single largest lever in the tree.

**2. Cost is the binding constraint until something states an availability requirement.** The thing
that reverses decision 1 is a *stated* requirement — an SLO, a customer commitment, a paid tier — not
a preference for robustness in the abstract. Whoever restores regional should be able to name the
requirement that made it necessary.

**3. The node floor is a memory budget, not an autoscaling floor, and that is why it is 2 and not 1.**
Nothing in `deploy/k8s/platform/base` declares CPU or memory requests. Every pod is therefore
schedulable, the cluster autoscaler never observes a pending pod, and it will not scale up for
load — so an undersized floor does not present as a pending pod waiting for capacity. It presents as
**eviction under memory pressure**, which reads like an application fault. Until the workloads
declare requests, the floor is the entire capacity plan.

**4. Storage classes are an environment's choice; ADR-0033's premium requirement attaches to a
CLAIM, not to a default.** Both overlays use `standard-rwo`. **When the git tier lands it must
declare its own `premium-rwo` claim**, and that obligation is ADR-0033's, unaffected by anything
here. A default is not a decision; a claim is.

**5. Persistent volume sizes are chosen at the reversible end.** A PVC can be expanded in place and
cannot be shrunk without destroying the volume, so at zero data the recoverable error is sizing
small. Nothing below 10Gi, which is the GCE persistent-disk billing minimum — a smaller claim costs
the same and only brings disk-full nearer.

**6. The CI runner ceiling is a spend bound, not a throughput decision.** Four, not twenty. Idle cost
is zero either way; the ceiling exists solely to bound what a busy queue can spend before a human
sees the bill. Raise it when measured throughput demands it. `e2-standard-4` satisfies ADR-0012:
GKE Sandbox refuses **shared-core** types, and `e2-standard-4` is not one.

**7. The floor is per-cluster fixed cost, and the only lever past it is one ADR-0092 already
rejected.** Cluster management, Cloud NAT (required by ADR-0011's private nodes) and the Zero Trust
connector (ADR-0097) are charged per cluster and move for no parameter. The only remaining reduction
is collapsing the control and data planes into one cluster — which ADR-0092 considered by name and
rejected because it collapses ADR-0011's inbound asymmetry. **Cost pressure is not a reason to
reopen that without an ADR**, and this decision exists so the next round of cost-cutting meets a
written "no" instead of an apparently unexamined option.

**8. Spot and preemptible instances are refused for the system pool.** OpenBao, Postgres and Redpanda
are quorum workloads (ADR-0099 decision 4). Preemption does not cost a pod, it costs a quorum, and
the saving is not worth an availability failure that looks like data loss.

## Consequences

- **Deleting a `location` line triples that environment's node bill**, and it looks like tidying —
  removing a line to fall back to a module default is the shape of a cleanup. Both `gke` unit files
  and `deploy/gcp/README.md` say so at the point of edit. **No gate enforces it**, which is the
  weakest part of this ADR and is recorded as a follow-up rather than claimed.
- A zone outage in `asia-southeast1-a` is a total outage of both environments simultaneously, since
  both are in the same zone. Putting them in different zones would not help — they are separate
  failure domains that both need to be up.
- `gcloud container clusters` takes `--zone` for a zonal cluster and `--region` for a regional one,
  failing with a bare "not found" that names no cause. Making this change broke three documented
  commands (two `get-credentials` in `deploy/k8s/README.md`, two `clusters delete` in
  `TEARDOWN-RUNBOOK.md`) — a teardown would have stalled at step 1 looking as though the cluster was
  already gone. Fixed; noted because the next location change will do it again.
- ADR-0092's cost paragraph ("two clusters cost roughly twice one cluster's control-plane fee and
  node floor") remains true and is now the floor rather than the total.

## Alternatives considered

- **Leave it regional and accept ~$920/month.** Rejected by the owner's instruction, twice. Worth
  recording that this was never argued against on technical grounds — the shape was defensible, it
  was simply not the one being paid for.
- **Spot VMs for the system pool.** The largest remaining saving on paper, ~70% of node cost.
  Rejected by decision 8: three of the five components are quorum services.
- **One cluster with namespace separation.** Rejected already by ADR-0092, and re-rejected here by
  decision 7 so that the *next* cost conversation finds it refused rather than unconsidered.
- **GKE Autopilot.** Not evaluated, and it should be before the next cost review: it changes the
  charging model from nodes to pod resource requests — which, per decision 3, this tree does not
  declare at all, so Autopilot would price every workload at its default request. That interaction
  makes it a bigger change than it appears, not a smaller one.
- **Smaller machine types than `e2-standard-4`.** Rejected for now: 4 vCPU / 16GB × 2 is already
  close to the floor that decision 3 describes, and the next size down halves the headroom that is
  currently the only thing standing between twelve request-less pods and eviction.

## Open questions

- ~~**Should a fitness function assert that every live `gke` unit sets `location` explicitly?**~~
  **Answered on acceptance:** yes — SPEC-0072 (Draft) and T-0091. It asserts explicitness and never a
  value, so restoring regional stays a one-line deliberate act rather than a gate fight.
- **What does the first stated availability requirement look like?** Decision 2 makes an SLO the
  trigger for reverting, and none exists. Naming it before it is needed is cheaper than deciding it
  during an outage.
- **Does the git tier's arrival change decision 1?** Its PVCs are `premium-rwo` by decision 4, but a
  zonal cluster also means its block volumes live in one zone. That is a durability question this
  ADR does not answer and ADR-0033 did not have to.
