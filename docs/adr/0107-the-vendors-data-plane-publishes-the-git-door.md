# ADR-0107: The vendor's own data plane publishes the Git door

- **Status:** Accepted
- **Date:** 2026-09-23
- **Deciders:** platform; **accepted by the deciding owner on 2026-09-23** ("approve ADR-0107")
- **Answers:** ADR-0095 decision 11, which left this open in as many words
- **Relates to:** ADR-0011 (outbound-only — the property this must not weaken), ADR-0041 (the front
  doors terminate in the data plane), ADR-0092 (prod-dp is the vendor as its own first customer),
  ADR-0094 (the repository surface moves data-plane-side), ADR-0095 (the control plane's public
  surface and the proxy rules), ADR-0096 (Kustomize only; decision 3 reserves `deploy/k8s/dataplane/`
  for the BYO installer), ADR-0106 (cost is the binding constraint)
- **Invariants:** 12 (this ADR exists because of it), 9, 2

## Context

**A Git SaaS with no public path to its Git front door is not a Git SaaS.** That is the whole of the
problem, and it has been invisible because every artefact that touches it is individually correct.

ADR-0041 decision 1 puts Smart-HTTP and SSH inside `cmd/dataplane-app`. ADR-0094 decision 3 moves the
repository surface data-plane-side. ADR-0092 decision 2 makes `prod-dp` the vendor as its own first
customer. Each is right. Together they put the only surface a customer ever types into a cluster that
`deploy/gcp/modules/addresses` describes as one that *"reserves nothing, publishes nothing, and has
no inbound path at all (ADR-0011)"*.

**That sentence cites ADR-0011 for something ADR-0011 does not say.** ADR-0011 governs the
*management* channel: the agent opens an outbound-only connection so a customer need not open inbound
holes *in their own network*. It says nothing about the tenant-facing Git protocol, which ADR-0041
had already terminated in the data plane. The BYO installer is right to render no inbound surface —
a customer's cluster is reached by their own ingress, on their terms. The vendor's data plane is the
opposite case: it **is** the product's public surface, and nobody else will publish it.

ADR-0095 decision 11 saw the gap and deliberately declined it:

> **11. The vendor's own data plane (`prod-dp`) publishes nothing under this ADR.** Whether `prod-dp`
> exposes an ADR-0094 door is already an open question against ADR-0092/0094.

Invariant 12 makes that a decision to take rather than to inherit. This ADR takes it.

**Two facts measured on the live cluster on 2026-09-23, which constrain the shape rather than
decorate it.**

- **The Git front door speaks plain HTTP and has no TLS listener at all.** `startGitFrontDoors`
  builds `&http.Server{Handler: mux}` and calls `Serve(listener)`, never `ServeTLS`, and no TLS
  environment variable exists. TLS must therefore terminate *in front of* the plane. That is not a
  gap to fix here; it is the deployment contract ADR-0041 decision 1 already states ("TLS termination
  and listener addresses are environment configuration").
- **The door answers 404 to `/`, to `/healthz` and to `/git/` alike.** It serves only real Git
  transport paths. A GKE Gateway derives its health check from neither the readiness probe nor the
  Service, defaults to `GET /` expecting 200, and so marks this backend permanently unhealthy while
  every pod reports Ready. The same defect took `auth-gitfrok` down for an hour on 2026-09-22.

## Decision

**1. `prod-dp` publishes exactly one public surface: the Git door, at
`git-gitfrok.7.solutions`.** One hostname, one reserved global address (`prod-dp-git-gateway`), one
`HTTPRoute`, and one path prefix — `/git/`. Nothing else on the plane becomes reachable by adding
this. The LFS batch route lives under the same prefix and is therefore published with it, which is
intended; every other handler stays unreachable by default rather than by omission.

**2. The record is DNS-ONLY in Cloudflare, and that is a correctness requirement, not a preference.**
ADR-0095 decision 3 makes `agents-gitfrok` DNS-only because a proxy that terminates TLS breaks
certificate pinning. `git-gitfrok` is DNS-only for a different and equally hard reason: **Cloudflare's
proxy caps request bodies**, and a `git push` is a single request whose body is the whole pack. A
proxied Git host works for every small push and fails on the first large one — the worst failure
shape available. `app-gitfrok` and `auth-gitfrok` remain proxy-optional under ADR-0095 decision 5;
this decision does not touch them.

**3. TLS is a Google-managed certificate from Certificate Manager, attached to the Gateway by
certificate map.** Not cert-manager, and not a self-signed origin behind a Cloudflare edge
certificate. The reasons are ordered: a DNS-only record means there is no edge certificate to hide
behind, so the origin must be browser-trusted and `git`-trusted on its own; a managed certificate
renews with nothing in the cluster holding a private key or an ACME account; and `prod-dp` runs **no
cluster-wide operator today** — adopting cert-manager here would install one, with an admission
webhook and cluster-scoped RBAC, to serve a single hostname. ADR-0095 decision 7's intent — real
certificates at the origin, no third party in the TLS path — is met; its named mechanism is not, and
this ADR is the place that says so out loud rather than letting the tree drift.

**Corrected before acceptance, same day.** The Proposed text gave a third reason: that cert-manager's
ACME HTTP-01 Gateway solver was "still unresolved on the control plane". It was fixed hours later —
`--enable-gateway-api` is a second controller flag the feature gate does not imply, and the static
release manifest ships no Gateway API RBAC — and it now issues Let's Encrypt certificates for
`app-gitfrok` and `auth-gitfrok`. That reason is withdrawn rather than left to mislead; the two that
remain carry the decision on their own.

**4. A `HealthCheckPolicy` is part of the installer, not an operator fix-up.** It targets the
`dataplane` Service, probes `/healthz` on port **8080** with `USE_FIXED_PORT` while traffic is served
on 8081, and exists because the measurement above says the serving port has no 200-answering path. An
installer that ships the route without the policy ships a 502.

**5. The first-party overlay lives at `deploy/k8s/dataplane/overlays/prod-dp/`, and the BYO bundle
will live under `deploy/k8s/dataplane/byo/` when T-0085 lands.** They share `base/` for the workloads
and differ in exactly one property — this one. Keeping them in one tree makes the difference legible
and diffable; putting the first-party overlay somewhere else would hide the only thing worth
reviewing. **ADR-0096 decision 3 is amended to this extent and no further:** `deploy/k8s/dataplane/`
is the data-plane installer tree, of which the BYO bundle is one consumer rather than the only one.

**6. `prod-dp` still opens no inbound path for management.** The agent channel stays outbound-only
(ADR-0011), the Kubernetes endpoint stays private, and the operator path stays IAP + SOCKS
(ADR-0097). This ADR publishes a tenant protocol and nothing else; no control-plane reachability, no
administrative surface, no second route.

**7. SSH is NOT published, and that is stated rather than deferred silently.**
`GITFROK_GIT_SSH_ADDR` exists in `cmd/dataplane-app` and is set in **zero** deployments in this tree.
An L7 Gateway cannot carry SSH, so publishing it needs an L4 passthrough address of its own — a
second decision with its own host-key custody question (a rotating host key is a fleet-wide
`known_hosts` break). Clone-over-HTTPS is the shipped path; SSH is a follow-up, not an omission.

## Consequences

**Positive.**
- The product becomes reachable. `git clone https://git-gitfrok.7.solutions/git/<tenant>/<repo>.git`
  is a thing a person outside the cluster can type, which no artefact in this tree previously made
  true.
- The BYO installer's defining property is preserved *and made explicit*: it renders no inbound
  surface because a customer's cluster must not, not because inbound surfaces are wrong.
- TLS leaves the Cloudflare edge for this hostname, which is a step toward ADR-0095 decision 7's
  intent rather than away from it.

**Negative / costs.**
- **A second Gateway is a second GCLB**, with its own forwarding rules and its own monthly cost.
  ADR-0106 made cost the binding constraint and this spends against it; the alternative — routing Git
  through the control plane's Gateway — would put tenant Git traffic through the control plane, which
  ADR-0041 and ADR-0094 both refuse.
- **`git-gitfrok` loses Cloudflare's WAF and DDoS mitigation**, which decision 2 buys deliberately.
  The Git door is authenticated on every request (PAT over HTTP Basic, then a PDP decision in
  `git-storaged`), so the exposure is rate and volume, not authorization.
- **One more certificate to watch.** Managed renewal is automatic, but a DNS authorization whose
  CNAME is deleted stops renewing silently. That record is now load-bearing and nothing gates it.

**Neutral.**
- This does not make `prod-dp` a second control plane, and does not give it one. It publishes one
  protocol on one prefix.

## Alternatives considered

- **Publish nothing and keep Git internal.** Honest to ADR-0095 decision 11 as written, and it means
  the product does not exist. Rejected.
- **Route `git-gitfrok` through the control plane's existing Gateway to a cross-cluster backend.**
  Saves a GCLB. Puts tenant Git bytes through the control plane, which is exactly the coupling
  ADR-0041 decision 1 and ADR-0094 were written to prevent, and creates a cross-project NEG
  dependency for the product's hottest path. Rejected on architecture, not on cost.
- **Proxy `git-gitfrok` through Cloudflare like `app-` and `auth-`.** Gains WAF. Breaks `git push`
  above the proxy's body cap, intermittently and by size. Rejected — see decision 2.
- **cert-manager ACME at the origin, per ADR-0095 decision 7's named mechanism.** Preferred on
  principle, and proven working on the control plane since 2026-09-23. Not adopted here because it
  would bring a second cluster-wide operator, admission webhook included, onto a plane that runs none,
  for one hostname. Revisit if the data plane publishes a second hostname; this decision's TLS half is
  the part to revisit.

## Follow-ups

- **SSH (decision 7)** needs its own ADR: an L4 address, host-key custody and rotation.
- **No gate reads `deploy/k8s/dataplane/`.** `check-platform-kustomize.sh` and
  `check-controlplane-kustomize.sh` are hard-coded to their own trees, so this overlay is
  unasserted — no secretGenerator walk, no authored-Secret refusal, no storage-class check. That is a
  task, and it should be filed before this ADR is Accepted rather than after.
- **`agents-gitfrok` must stay `proxied=false`.** It is verified so today; nothing enforces it.
