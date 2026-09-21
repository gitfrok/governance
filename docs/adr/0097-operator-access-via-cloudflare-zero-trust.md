# ADR-0097: Operator access to the Kubernetes API goes through Cloudflare Zero Trust, and both clusters' endpoints go private

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** platform (the deciding owner ruled, reversing the open-endpoint choice made earlier the same day)
- **Amends:**
  - **ADR-0092 decision 2 in part** — the control plane's cluster endpoint becomes **private**, so the
    table's "public endpoint, authorized-networks restricted" row no longer describes `prod-cp`. The
    application surface is untouched; this is the *Kubernetes API*, not the product.
  - **ADR-0095 decision 8 in part** — a Cloudflare **tunnel** credential now exists in the
    deployment, where that decision said none would. Its terms are narrowed rather than dropped: see
    decision 4. The DNS credential that decision was actually written about stays barred.
  - Neither ADR is edited (ADR-0001).
- **Related:** ADR-0009 (plane split), ADR-0011 (outbound-only — this extends its asymmetry to the
  management plane), ADR-0010 (portability), ADR-0017 (the agent's mTLS door, **unaffected**),
  ADR-0066 (custody), ADR-0092 (the first-party cloud), ADR-0095 (the public surface — three flat
  Cloudflare names), ADR-0096 (Kustomize installers)
- **Governs:** G1 isolation, G4 change governance, operability

## Context

Earlier on 2026-09-22 the deciding owner was offered three ways to gate the control plane's
Kubernetes API and chose an unrestricted public endpoint, which `live/prod-cp/env.hcl` now records at
length as an accepted exposure. The owner has since directed **Cloudflare Zero Trust instead**. This
ADR records the reversal and works out what it costs, because it is not a smaller change than it
sounds: the API endpoint's reachability is fixed by ADR-0092 decision 2's table, and a Zero Trust
connector needs a credential ADR-0095 decision 8 said would not exist.

**What this is not.** Zero Trust here covers the **operator's path to the Kubernetes API** only. It
does not touch the three public application hostnames ADR-0095 decided:

- `app-gitfrok.7.solutions` and `auth-gitfrok.7.solutions` are a **multi-tenant SaaS surface and its
  OIDC issuer**. Customers reach them. Putting them behind Cloudflare Access would gate paying
  tenants behind the vendor's identity provider, which is a different product.
- `agents-gitfrok.7.solutions` **cannot** go behind Access or any proxy at all, for the reason
  ADR-0095 force 1 establishes: the agent pins our CA to verify the server certificate and an
  intermediary that terminates TLS is simply untrusted by it.

So the surface stays as ADR-0095 decided, and this ADR is about the door operators use, which until
now was either a public API or nothing.

**Zero Trust is already in production on this account, which is the fact that makes this decision
cheap.** Verified read-only against the Cloudflare API on 2026-09-22 for account `7 Solutions`: **6
Cloudflare Tunnels, 17 Access applications and 2 Access identity providers** already exist, and
Gateway is configured. So this is not the adoption of a new vendor, a new identity integration or a
new operational practice — it is one more application on a platform the organization already runs,
whose operators plausibly already have WARP enrolled. Every "new dependency" cost below should be
read against that: the dependency exists already and this decision widens what rests on it rather
than creating it.

**One fact decides the connector's placement.** A Cloudflare Tunnel connector is usually deployed as
an in-cluster `Deployment`, and that cannot work here. Reaching a **private** Kubernetes API to
install the workload that provides access to that API requires the access it has not yet provided.
The connector must therefore live **outside** the cluster it fronts. That is not a preference; an
in-cluster connector is unbootstrappable on a private endpoint.

Two further constraints follow from existing decisions. ADR-0092 decision 4 forbids OpenTofu from
creating any Kubernetes object, and ADR-0096 decision 4 limits the installer to the three first-party
workloads — so an in-cluster connector would also be a workload with no owner, in the same gap
cert-manager and `external-dns` sit in. And ADR-0092 decision 6 forbids a secret from being an
OpenTofu input, which shapes how the tunnel token reaches the connector.

## Decision

**1. Both clusters' Kubernetes API endpoints are private.** `prod-cp` gets
`enable_private_endpoint = true` and `master_authorized_networks = []`, which is exactly the shape
`prod-dp` already has and which ADR-0092 decision 2 called "ADR-0011's no inbound path made
structural". The asymmetry that ADR stated between the two planes was never about the *management*
plane; both now agree that nothing reaches the API from the internet.

**2. Operators reach the API through Cloudflare Zero Trust, over a tunnel from inside the VPC.**
Cloudflare Access policies authorize the human; WARP routes the operator's traffic to the private
master CIDR; a `cloudflared` connector inside the VPC terminates it. There is no public endpoint and
no authorized-network list to maintain, which is the property that makes this better than the CIDR
allow-list originally offered: an allow-list authenticates a *network location*, and Access
authenticates a *person*.

**3. The connector runs on a small GCE VM that OpenTofu provisions, not in the cluster.** Forced by
the bootstrapping fact above, and it happens to resolve the ownership problem: a VM is
**infrastructure**, so ADR-0092 decision 4 permits OpenTofu to create it, whereas a `Deployment`
would have been a workload with no owner. One `e2-micro`/`e2-small` per environment that needs
operator access, in the same VPC, with no public IP and egress through the Cloud NAT that already
exists.

**4. The tunnel token is a GCP Secret Manager secret whose *value* OpenTofu never sees.** OpenTofu
creates the secret **container** and grants the VM's service account access to it; an operator adds
the version out of band, as a named manual seam in the runbook beside the three ADR-0093 decision 4
already has. This is how ADR-0095 decision 8 is narrowed rather than abandoned:
- **Still barred:** a Cloudflare **DNS** credential in the cluster or in OpenTofu. That is what
  decision 8 was written about — a token with write access over the whole `7.solutions` apex zone —
  and nothing here needs one. ADR-0095 decision 7's HTTP-01 issuance is unchanged.
- **Now permitted:** a Cloudflare **tunnel** credential, on a VM, outside the cluster, scoped to one
  tunnel. It cannot edit DNS, cannot read the zone, and its blast radius is the tunnel it names.
- **Still true literally:** no Cloudflare credential enters the **cluster**, and none is an
  **OpenTofu input**.

**5. A break-glass path is named, because Zero Trust is now a single point of failure for
administration.** If Cloudflare Access is unavailable, nobody can reach either cluster's API. The
recorded fallback is temporarily adding an operator CIDR to `master_authorized_networks` with
`enable_private_endpoint = false` — a two-line, reviewable, revertible change in `env.hcl` that
returns the cluster to the posture decision 1 replaced. It is written down because an undocumented
break-glass becomes an improvised one during an incident.

**6. `prod-dp` is unchanged in shape and gains the same door.** Its endpoint was already private with
no authorized networks; it gets a connector VM so the reference data plane is administrable at all.
This opens **no inbound path to the data plane's workloads** and does not touch ADR-0011: the tunnel
is outbound from the VM, reaches only the Kubernetes API, and carries no agent traffic and no
repository data.

## Consequences

**Positive:**
- The open public Kubernetes API accepted earlier today is gone, and the exposure note in
  `env.hcl` gets deleted rather than merely qualified.
- Access authenticates a person, not a network location, so a laptop on a coffee-shop network is
  handled correctly and an operator CIDR never needs maintaining.
- Decision 3 keeps the workload-layer boundary intact: nothing new is a Kubernetes object, so
  ADR-0092 decision 4 and ADR-0096 decision 4 both stand unamended.
- Decision 1 makes both clusters agree, which removes the "why is one public" question from every
  future reader of ADR-0092's table.
- The connector VMs reuse the Cloud NAT both networks already provision; no new egress path.
- **Nothing here is a first**: 17 Access applications, 6 tunnels and 2 identity providers are already
  live on this account, so the pattern, the IdP wiring and the operator habit all exist. The marginal
  cost of this decision is a VM and a tunnel, not a platform.

**Negative / costs:**
- **Cloudflare becomes a dependency of administration, not just of DNS.** If Access is down, the API
  is unreachable — hence decision 5. This is a genuine reduction in independence and it is the main
  cost here. It is *concentration* rather than a new dependency: ADR-0095 already put all three
  public records in this vendor's zone, and this adds the management plane to the same failure
  domain. One outage now takes the product's DNS and the operators' ability to respond to it.
- **Two more VMs to own**: patching, and the connector's own version. Small, and not nothing.
- **A second Cloudflare credential exists** where ADR-0095 decision 8 said there would be none.
  Decision 4 narrows it honestly rather than pretending the decision is untouched.
- **An operator now needs WARP installed and enrolled** to do anything, including during an incident
  when that is least welcome.
- **`prod-cp`'s endpoint flip is a create-time property in practice.** Toggling
  `enable_private_endpoint` on a live cluster is not reliably in-place across provider versions, so
  this decision wants to land **before** the first `terragrunt apply` — which it can, since no
  cluster exists yet. That timing is the reason this ADR is worth writing today rather than after.
- Reaching the API from CI (rather than from a human) now needs a service token or a separate path,
  and nothing here decides it.

**Follow-ups:**
- The implementing **spec and task**: the connector VM module, the Secret Manager container and its
  IAM binding, the `env.hcl` changes, and the runbook seam for the token.
- **The Cloudflare-side configuration is not in this tree**: the tunnel, the Access application, the
  policies and the private-network route are created in the Cloudflare dashboard or by API. Whether
  that configuration is captured as code, and where, is undecided — and it is the same question
  ADR-0095 decision 4 left hanging when it put three DNS records in a vendor console.
- **CI's path to the API**, per the last negative.
- Whether the break-glass of decision 5 gets a rehearsal, since an untested fallback is a hope.
- The reserved static addresses of ADR-0095 decision 6 remain open and unaffected.

## Alternatives considered

- **The open public endpoint accepted earlier today** (`admin_networks = []`,
  `private_endpoint = false`). Zero new components, zero new dependencies, and an unauthenticated
  network path to the API of a multi-tenant control plane. **Reversed by owner direction**, and the
  reversal is an improvement: what was accepted was an exposure, not a design.
- **An operator CIDR allow-list**, the option originally offered alongside it. Simpler than this ADR
  by a wide margin and needs no Cloudflare. Rejected by the same direction; recorded because it is
  the shape decision 5's break-glass returns to, so it must stay understood rather than forgotten.
- **An in-cluster `cloudflared` Deployment**, the idiomatic Cloudflare pattern. Rejected on the
  bootstrapping fact: it cannot be installed through the private endpoint it would provide. It would
  also be an ownerless workload and would put a Cloudflare credential in a cluster Secret, which is
  the thing ADR-0095 decision 8 most clearly meant to prevent.
- **IAP TCP forwarding**, Google's own equivalent, which needs no third party and no VM — the
  operator runs `gcloud compute start-iap-tunnel` against a bastion, authorized by GCP IAM. It keeps
  administration inside the cloud whose four APIs ADR-0092 already accepted and adds no Cloudflare
  dependency, so it is the strongest alternative on independence grounds. Rejected by the owner's
  direction to use Cloudflare Zero Trust; recorded in full because it is what a reviewer will ask
  about, and because it remains the answer if decision 5's fallback is ever exercised twice.
- **A bastion host with SSH keys**, the traditional answer. Rejected: it reintroduces long-lived
  credentials and a host to harden, which is what both Zero Trust and IAP exist to remove.
- **Leaving `prod-dp` alone with no operator door.** Cheaper, and defensible since it is a reference
  deployment. Rejected under decision 6: a cluster nobody can administer cannot be debugged when the
  thing it is a reference for breaks.
