# ADR-0092: GCP is the first-party cloud, and OpenTofu + Terragrunt provisions it

- **Status:** Accepted
- **Date:** 2026-08-25
- **Deciders:** platform (requested by the deciding owner)
- **Related:** ADR-0009 (control-plane / data-plane split), ADR-0010 (GKE/EKS/AKS via a
  Kubernetes-API-first portability layer), ADR-0011 (outbound-only agent), ADR-0012 (gVisor as the
  default CI isolation), ADR-0013 (Helm chart + Operator packaging), ADR-0024 (Minikube is the *dev*
  environment), ADR-0027 (submodule topology; invariants 21–25), ADR-0034/0035/0047 (image pins,
  first-party images, public pullability), ADR-0040 (Apache-2.0 across the tree), ADR-0066 (OpenBao
  is the control-plane custody service), ADR-0089 (technology stack rev. 4)
- **Governs:** G1 isolation, G6 compliance, G7 residency

## Context

Every environment this system has ever had is a laptop. ADR-0024 fixed Minikube as the dev cluster
and `deploy/dev/*.yaml` as its manifests; ADR-0013 fixed the Helm chart + Operator as how a *customer*
installs a data plane. Nothing states where the **vendor-run control plane** runs, and nothing states
how any cloud account reaches the shape a cluster needs before a chart can be installed into it.
There is no infrastructure-as-code in the tree — `find . -name '*.tf' -o -name '*.hcl'` returns
nothing.

Three forces meet here.

1. **ADR-0009 makes the control plane ours to host.** The data plane is the customer's problem by
   design; the slim multi-tenant control plane is not. It needs a real home with a real address,
   because ADR-0011's agent dials *in* to it.
2. **ADR-0010 already chose the portability posture** — depend on Kubernetes APIs, not cloud APIs.
   Picking a cloud must not quietly spend that. Whatever we provision has to leave the port to
   EKS/AKS as a swap of one layer, not a rewrite.
3. **The gap is provisioning, not deployment.** A cluster, a network, a registry and a DNS zone are
   not workloads; no chart creates them, and creating them by hand in a console is the kind of
   undocumented state this repo exists to refuse.

Two constraints narrow the tool choice before preference does. Terraform is BUSL-1.1 since 1.6, which
is a licence we cannot read as safely as the MPL-2.0 fork given ADR-0040's Apache-2.0 posture across
the tree. And the shape of the problem — the *same* cluster definition instantiated twice, once for
the control plane and once for a data plane, with per-environment inputs and no copy-pasted backend
blocks — is precisely the shape Terragrunt exists for.

## Decision

**1. GCP is the first-party cloud.** The vendor-run control plane runs on **GKE**. This is a choice
about *our* hosting only. ADR-0009 and ADR-0010 are untouched: customer data planes remain BYO on
GKE, EKS or AKS, and nothing here makes GCP a requirement for a customer.

**2. Two clusters in two projects, not one cluster.** The control plane and the vendor's own data
plane are separate GKE clusters in separate GCP projects:

| | control plane (`cp`) | data plane (`dp`) |
|---|---|---|
| Holds | multi-tenant metadata, billing, custody, release service | repos, CI, blobs — one tenant's workloads |
| Inbound | **yes** — agents dial in (ADR-0011), and the app surface is public | **none** (ADR-0011) |
| Cluster endpoint | public endpoint, authorized-networks restricted | **private**, Cloud NAT for egress |
| CI sandbox | not applicable | GKE Sandbox / gVisor node pool (ADR-0012) |

The vendor's data plane is **the vendor as its own first customer** — a reference deployment, not a
second control plane and not an exception to ADR-0009's topology. It installs the ADR-0013 chart and
enrols over the same outbound channel a customer's would.

**3. OpenTofu, orchestrated by Terragrunt.** OpenTofu (MPL-2.0) is the executor; Terragrunt is the
orchestrator that supplies the backend, the provider block and the per-environment inputs. Versions
are constrained in `root.hcl` rather than asserted from a shell — `terraform_version_constraint` and
`terragrunt_version_constraint`, pinned to the OpenTofu 1.12 and Terragrunt 1.1 lines and the
`hashicorp/google` 7.x provider.

**4. OpenTofu provisions infrastructure. It never provisions a workload.** The line is the
Kubernetes API: if a thing is a Kubernetes object, OpenTofu does not create it — not a Deployment,
not a StorageClass, not a namespace, not a Helm release. That side of the line already has owners
(ADR-0013's chart and Operator for the data plane; `deploy/dev` for dev). OpenTofu's units end at:
enabled project APIs, VPC + subnets + NAT, the GKE cluster and its node pools, Artifact Registry, the
Cloud DNS zone, and the Google service accounts that Workload Identity binds to.

**5. Every stateful dependency stays in-cluster.** Postgres, Valkey, Redpanda, SeaweedFS, OpenBao and
Zitadel run in the cluster on the exact image pins `deploy/dev/versions.env` already records
(ADR-0034). We provision **no** Cloud SQL, **no** Memorystore, **no** Pub/Sub, **no** GCS bucket for
blobs. This is ADR-0010 being spent deliberately and minimally: the only cloud APIs we take a
dependency on are the four that have no Kubernetes equivalent — the cluster itself, the network, the
image registry, and DNS.

**6. State lives in a versioned GCS bucket per environment**, created by Terragrunt's own `remote_state`
bootstrap, with GCS-native locking. No state file is ever committed, and no secret is ever an input:
custody is OpenBao's (ADR-0066), and its unseal remains Shamir — this ADR authorizes no Cloud KMS
seal and no second custody service.

**7. The code lives in the super-repo, at `deploy/gcp/`.** `deploy/dev` and `deploy/helm` are already
tracked directly in the super-repo, and infrastructure is not product source: it has no place in
invariant 22's one-way dependency chain, so giving it a submodule would invent a fifth repo to hold
files that depend on nothing but governance. Ordering follows invariant 24 — this governance commit
first, the `deploy/gcp/` commit second, never one commit spanning both (invariant 23).

**8. Region is an input, defaulted to `asia-southeast1`,** because residency is a per-deployment fact
(G7, ADR-0063/0067) and not a property of the tool.

## Consequences

**Positive:**
- The control plane gets a home that is reviewable, diffable and reproducible, which is the first
  time that sentence has been true of any environment but a laptop.
- Decision 4 keeps ADR-0013 the single owner of workload deployment, so there is no second, drifting
  copy of what runs where.
- Decision 5 keeps ADR-0010 honest: porting to EKS or AKS replaces four units and touches nothing
  else, because nothing above the cluster knows which cloud it is on.
- Decision 2 makes ADR-0011's asymmetry structural rather than aspirational — the data-plane cluster
  has no public endpoint to forget to close.

**Negative / costs:**
- Running Postgres, Redpanda, SeaweedFS and OpenBao ourselves is an operational bill that Cloud SQL
  and Memorystore would have absorbed: backups, upgrades, failover drills and page-able storage are
  now ours in production, not just in dev.
- Two clusters cost roughly twice one cluster's control-plane fee and node floor, for a data plane
  that initially serves one tenant.
- A second IaC toolchain enters the host toolchain set. It is constrained in `root.hcl`, which means
  `check-version-floors.sh` does **not** see it — see follow-ups.
- GKE Sandbox constrains the runner pool to `COS_CONTAINERD` and costs some syscall performance, the
  cost ADR-0012 already accepted, now with a node-pool shape attached to it.

**Follow-ups:**
- **The control plane has no chart.** `deploy/dev/*.yaml` is Minikube-only by ADR-0024, and ADR-0013's
  chart is the *data-plane* installer. Nothing can deploy the control plane to the cluster this ADR
  provisions. That is a separate decision — a control-plane chart, or ADR-0013 extended — and it
  blocks a first real deployment.
- Whether `.tool-versions` should carry OpenTofu and Terragrunt floors so `check-version-floors.sh`
  gates them, rather than leaving the constraint inside `root.hcl` where no gate reads it.
- Ingress, DNS and certificate issuance for the public control-plane surface: `deploy/dev` uses an
  nginx Ingress with an mkcert wildcard, and the production answer (Gateway API vs nginx, cert-manager
  issuer, `external-dns`) is unmade. ADR-0010 §3 names Gateway API as the portable candidate.
- Backup and restore for the in-cluster stateful set that decision 5 keeps ours. Decision 5 accepts
  the obligation; nothing yet discharges it.
- A staging environment. The live hierarchy is shaped for it, and only `prod-cp` and `prod-dp` exist.
- Whether Artifact Registry becomes the publish target for first-party images, which ADR-0047 leaves
  to whatever registry can be verified offline.

## Alternatives considered

- **Terraform (HashiCorp)** — BUSL-1.1 since 1.6. The state files and HCL are compatible either way,
  so the switching cost is near zero, and taking the permissive fork costs nothing today.
- **Pulumi** — real programming languages against real cloud SDKs. Rejected because the thing being
  described is nine resources of static topology, where a general-purpose language buys expressiveness
  we do not need and a runtime we would have to gate.
- **Crossplane / Config Connector** — provision cloud infrastructure *from* Kubernetes. Genuinely
  attractive under ADR-0010, and rejected for one reason: it needs a cluster to bootstrap the cluster.
  Worth revisiting once a control-plane cluster exists to host it.
- **gcloud scripts in `scripts/`** — matches the existing `dev-up.sh` idiom. Rejected: imperative
  scripts have no plan, no drift detection and no state, which is the whole reason console clicking was
  unacceptable.
- **A fifth submodule for infrastructure** — rejected under decision 7; it would add a repo boundary
  with no dependency edge to justify it.
- **One cluster with namespace separation** — cheaper, and it collapses ADR-0011's inbound asymmetry
  into a NetworkPolicy. Rejected: the property worth having is that the data-plane cluster has no
  public endpoint at all.
- **Managed Cloud SQL + Memorystore** — the operational relief is real, and it is what the arch doc's
  portability table calls the customer's own choice. Rejected here under decision 5 to keep one
  production shape testable against the dev shape, and to keep the EKS/AKS port a four-unit change.
