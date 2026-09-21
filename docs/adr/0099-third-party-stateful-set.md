# ADR-0099: The third-party stateful set installs from Kustomize, with one operator where the failure is unrecoverable

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** platform (the deciding owner ruled)
- **Amends:** **ADR-0092 decision 5 in one narrow respect** — a GCS bucket is provisioned for
  **Postgres backups**. That decision refused "no GCS bucket **for blobs**", and a backup bucket is
  not a blob bucket; it is also the only way to discharge the obligation the same decision's own
  negative accepted ("backups, upgrades, failover drills and page-able storage are now ours in
  production"). Nothing else changes: no Cloud SQL, no Memorystore, no Pub/Sub, no blob bucket.
  ADR-0092 is Accepted and is not edited (ADR-0001).
- **Related:** ADR-0033 (block volumes for live repos), ADR-0034 (image pins), ADR-0050 (SeaweedFS
  serves large objects only), ADR-0052 (the BFF's session store; an unreachable store is fatal at
  startup), ADR-0066 (OpenBao: control-plane-side, 3-node Raft, Shamir quorum unseal, no static
  credentials), ADR-0092 (the first-party cloud; this discharges its stateful-set row), ADR-0093
  decision 2 (these five are **inputs** to the control-plane installer, not its contents), ADR-0094
  (the data plane's own surface), ADR-0096 (Kustomize only; Helm has left the tree), ADR-0097
  (private endpoints — nothing here is reachable from outside the VPC)
- **Governs:** G1 isolation, G6 compliance, operability

## Context

ADR-0093 decision 2 declared Postgres, Valkey, Redpanda, OpenBao and Zitadel **required inputs** to
the control-plane installer, and gave a reason that still holds: they are third-party software with
their own lifecycles, quorum procedures and migration ordering, and binding them to our application's
release cadence would make every app upgrade a database upgrade. It then recorded, honestly, that the
production install of those five "is now unowned by any artifact." That row has blocked a first
deployment through four ADRs and is the last thing standing between the tree and a login.

**`deploy/dev` is not a starting point in the way it looks.** It has a manifest for every component,
pinned by `versions.env`, and exactly one of them is production-shaped — OpenBao, whose StatefulSet
already runs the three replicas ADR-0066 decision 6 requires and which
`scripts/check-custody-service.sh` gates. The other five are **single-replica `Deployment`s with a
ReadWriteOnce PVC**, and that shape is not merely under-provisioned, it is wrong for a stateful
service: a rolling update cannot attach the volume the outgoing pod still holds, so the rollout
either stalls or completes only after the old pod dies, with no readiness overlap and a window where
the data is served by nothing. A single Postgres with no backup is worse than under-provisioned; it is
one disk from unrecoverable.

So this is a design, not a promotion. Three constraints shape it before preference does.

**1. Helm is gone (ADR-0096 decision 1).** The usual answer to "install Postgres in Kubernetes" is an
upstream chart, and that door is closed. What remains is a Kustomize base we author, or an operator
whose own installation is plain YAML — several are, which is the opening this ADR uses.

**2. ADR-0092 decision 5 keeps everything in-cluster, and already priced it.** No Cloud SQL, no
Memorystore. Its negative says plainly that "running Postgres, Redpanda, SeaweedFS and OpenBao
ourselves is an operational bill that Cloud SQL and Memorystore would have absorbed: backups,
upgrades, failover drills and page-able storage are now ours in production." This ADR is where that
bill is itemized rather than restated.

**3. The failures are not alike, and treating them alike is the mistake available here.** Losing
Valkey logs everyone out. Losing Redpanda loses in-flight events. Losing Postgres loses the product.
A uniform answer either over-engineers four components or under-protects one.

## Decision

**1. A Kustomize tree of its own, at `deploy/k8s/platform/`**, with `base/<component>/` and overlays
`prod-cp` and `prod-dp`. Deliberately **not** merged into `deploy/k8s/controlplane/`: ADR-0093
decision 2 made these inputs rather than contents, and putting them in the same overlay would
recreate the coupling that decision refused — every Postgres bump becoming a control-plane release.
`deploy/dev` is untouched (ADR-0024 owns it, and ADR-0096 decision 10 already declined to converge
them).

**2. Postgres is the one operator: CloudNativePG.** It is adopted because Postgres is the only
component here whose failure is unrecoverable, and because it supplies exactly the four things
ADR-0092 decision 5's negative admitted we would owe — backups, point-in-time recovery, rolling minor
upgrades, and failover — which a hand-written StatefulSet does not and which no amount of care
substitutes for. Its installation is a single plain manifest, so ADR-0096 decision 1 holds: no Helm
enters the tree. Two `Cluster` resources, one per plane, three instances each.

**3. Everything else is a `StatefulSet` with `volumeClaimTemplates`, never a `Deployment` with a
PVC.** This is the port that `deploy/dev` cannot supply, for the reason in the context: a `Deployment`
plus ReadWriteOnce cannot roll. It applies to Valkey, Redpanda, Zitadel and SeaweedFS alike, and it is
the single largest difference between the dev manifests and these.

**4. Replica counts are decided per component, and the small ones are decisions rather than
defaults:**

| Component | Plane | Replicas | Why this number |
|---|---|---|---|
| Postgres (CNPG) | cp, dp | 3 | one primary, two standbys; survives a node loss with a quorum left to elect |
| OpenBao | cp | 3 | ADR-0066 decision 6's Raft minimum; `check-custody-service.sh` already asserts it |
| Redpanda | cp, dp | 3 | a single broker cannot replicate, and the bus carries `CIJobFinished` and notifications that no consumer can reconstruct |
| Zitadel | cp | 2 | stateless given Postgres, so replicas buy availability and cost nothing in consistency |
| Valkey | cp | **1** | **deliberate.** It holds BFF sessions. Losing it logs everyone out, which is recoverable in a way losing Postgres is not, and Valkey HA needs Sentinel or Cluster mode — a second failure domain and a client-side change (ADR-0052) for a benefit measured in avoided re-logins. Revisit when session loss has a cost anyone has named |
| SeaweedFS | dp | 1 | ADR-0050 limits it to large objects; live repos are on block volumes (ADR-0033), so this is not the git hot path. Its replication is a data-plane question and this ADR does not settle it |

**5. Postgres backs up to a GCS bucket, and that is the one place this ADR spends ADR-0092 decision
5.** CNPG's backup target is object storage; there is no in-cluster answer that survives the cluster.
The bucket holds **backups only** — decision 5 refused a GCS bucket *for blobs*, which SeaweedFS still
serves — and it is provisioned by OpenTofu as a new `backups` unit, since a bucket is infrastructure.
Retention and PITR window are the follow-up; what this decision fixes is that backups exist and leave
the cluster.

**6. OpenBao terminates TLS in production, and the dev loopback proxy does not travel.** `deploy/dev`
sets `tls_disable=true` and runs a busybox TCP proxy sidecar so the custody adapter can reach it over
plain HTTP on loopback — the adapter admits that only there. `deploy/k8s/controlplane/base` already
names `https://openbao:8200` and omits both the sidecar and
`GITFROK_CUSTODY_ALLOW_LOOPBACK_HTTP`, so this decision is what makes that base honest rather than
optimistic. Everything `check-custody-service.sh` asserts is carried: three replicas, the
control-plane placement label, Shamir-only unseal with no seal stanza, no static credential, and the
ServiceAccount plus token-review delegation that makes Kubernetes auth the only client path.

**7. Every credential is created out of band and referenced by name.** The installer authors no
`Secret` and declares no `secretGenerator` (ADR-0093 decision 3, ADR-0096 decision 5) — including the
Postgres superuser, the application role, Zitadel's masterkey, and the `gitfrok-database` and
`gitfrok-pat-verifier` Secrets the control-plane installer already consumes by name. They become
named runbook seams beside ADR-0093 decision 4's three.

**8. Nothing here is publicly reachable.** No `Service` of type `LoadBalancer`, no `Gateway`, no
`HTTPRoute`. Zitadel is reached only through the control-plane Gateway's `auth-gitfrok` listener
(ADR-0095), and every other component is `ClusterIP`. Both clusters' API endpoints are already private
(ADR-0097), so the blast radius of a misconfiguration here stops at the VPC.

**9. It applies before the control-plane overlay, by the same mechanism.** ADR-0093 decision 5 chose
the release pipeline over an Operator and ADR-0096 decision 8 kept it. Ordering is not cosmetic: the
control-plane workloads fail their own startup contracts without these endpoints, and OpenBao is
sealed until a human quorum acts (ADR-0066 decision 4), so a correct install is still not a running
one.

## Consequences

**Positive:**
- The row that has blocked a first deployment through four ADRs closes, and the last structural
  blocker between this tree and a login goes with it.
- Decision 2 buys the backup and failover story ADR-0092 decision 5 promised and nothing delivered,
  for the one component where its absence is unrecoverable — and buys it without Helm.
- Decision 3 fixes a latent defect rather than scaling one: the dev shape would have rolled badly in
  production on its first upgrade, and it would have looked like a storage problem.
- Decision 4 makes each replica count answerable. Valkey at 1 is the kind of thing that otherwise
  reads as an oversight for years.
- Decision 6 makes `deploy/k8s/controlplane/base`'s `https://openbao:8200` true. It was written
  against a production posture that did not exist yet.
- Decision 8 keeps the whole set inside the VPC, so ADR-0097's private endpoints are not the only
  thing standing between a mistake and the internet.

**Negative / costs:**
- **One operator is still an operator.** CloudNativePG brings CRDs, a controller to upgrade, and its
  own release cadence — the cost ADR-0093 decision 5 declined for the control plane. It is accepted
  here for one component and should not be read as a precedent for the other four.
- **A GCS bucket appears** (decision 5), and with it the first storage outside the cluster. Small,
  scoped to backups, and still a widening of ADR-0092 decision 5's footprint.
- **Valkey is a single point of session loss**, by decision 4. Anyone paged for "everyone was logged
  out" should read that row first.
- **SeaweedFS's replication is undecided** and this ADR says so rather than defaulting it. A
  single-replica object tier on the data plane is adequate for ADR-0050's large-object scope and is
  not a durability answer.
- **Seven new credentials become manual seams** (decision 7). Each is a step a human performs before
  anything serves, and the runbook grows accordingly — which is the honest cost of authoring no
  Secret.
- **`check-custody-service.sh` is hardcoded to the dev path** and will need to learn a second one, or
  the production OpenBao manifest is ungated. That gap is worth naming: the gate currently proves
  properties about a Minikube file while production runs a different one.
- The stateful set is now ours to upgrade, in an order Postgres and Zitadel care about, and nothing
  automates that ordering.

**Follow-ups:**
- **SPEC-0069 and T-0086** — the implementing spec and task, filed with this ADR.
- **A gate for this tree**, in `check-controlplane-kustomize.sh`'s idiom: no `LoadBalancer`, no
  authored `Secret`, no `secretGenerator`, every image digest-pinned, every stateful component a
  `StatefulSet`, and the replica counts of decision 4 asserted so a silent scale-down is a failed
  build.
- **Teach `check-custody-service.sh` the production path**, per the cost above.
- **Retention and the PITR window** for decision 5's bucket.
- **The upgrade order** across Postgres, Zitadel and the control-plane app, which nothing currently
  states.
- **SeaweedFS replication** on the data plane.
- Whether Valkey's single replica is revisited once session loss has a named cost.

## Alternatives considered

- **Upstream Helm charts** — Bitnami Postgres, the Redpanda chart, Zitadel's own. The industry default
  and by far the least work. **Rejected by ADR-0096 decision 1**, which removed Helm from the tree
  entirely. Recorded because it is what a reviewer will ask about first, and because the cost of
  ADR-0096 is most visible right here.
- **Operators for all five** — CloudNativePG, the Redpanda operator, and so on. Best-in-class
  operationally. Rejected on footprint: five controllers, five CRD sets and five upgrade cadences to
  own for a control plane serving one tenant, when four of the five components have failure modes
  that a StatefulSet handles adequately. Decision 2 takes the one where that is not true.
- **Hand-written Postgres StatefulSet, no operator.** Consistent with the other four and one fewer
  thing to own. Rejected because it has no backup story, and "we will add backups later" is how
  unrecoverable data loss is scheduled. ADR-0092 decision 5 already accepted this obligation; this is
  the cheapest honest discharge of it.
- **Cloud SQL and Memorystore**, which would delete most of this ADR. Explicitly refused by ADR-0092
  decision 5 to keep one production shape testable against the dev shape and the EKS/AKS port a
  four-unit change. Revisiting it is a bigger decision than this one and would properly supersede
  that ADR rather than amend it.
- **Promoting `deploy/dev` unchanged.** Fastest, and it is what "the manifests already exist" suggests.
  Rejected under decision 3: five of the six are `Deployment` plus ReadWriteOnce, which cannot roll,
  and the single Postgres has no backup. It would deploy, then fail on its first upgrade in a way
  that reads as a storage fault.
- **Running the stateful set in one cluster and sharing it.** Cheaper than two of everything.
  Rejected: ADR-0092 decision 2's whole point is that the data-plane cluster has no public endpoint
  and no path in, and a shared database would be a path between planes that ADR-0011 forbids.
