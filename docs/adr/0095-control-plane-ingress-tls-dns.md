# ADR-0095: The public control-plane surface — three flat names in the Cloudflare `7.solutions` zone, a Gateway for the browser, and a CA-pinned passthrough door for the agent

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** platform (the deciding owner ruled)
- **Amends:** **ADR-0092 decision 4 in part** — Cloud DNS stops being one of the four cloud APIs this
  system depends on, and Cloudflare becomes an infrastructure dependency outside OpenTofu (ADR-0092
  is Accepted and is not edited; ADR-0001)
- **Related:** ADR-0009 (control-plane / data-plane split), ADR-0010 (GKE/EKS/AKS portability —
  §3 names Gateway API as the portable candidate), ADR-0011 (outbound-only agent), ADR-0017 (agent
  gRPC **client-certificate mTLS**), ADR-0024 (Minikube is the *dev* environment — nginx + an mkcert
  wildcard), ADR-0045 (Zitadel OIDC login), ADR-0060 (control-plane-issued short-lived agent certs),
  ADR-0066 (OpenBao is the custody service), ADR-0092 (GCP is the first-party cloud — **this
  discharges its ingress follow-up**), ADR-0093 (the control-plane chart — **this closes the seam its
  decision 6 opens**), ADR-0094 (the repository surface is served data-plane-side), SPEC-0002 (the
  dataplane door's recorded limit (d)), SPEC-0043 AC6 (a verified caller), SPEC-0044 (CA custody and
  staged trust-bundle rotation)
- **Governs:** G1 isolation, G4 change governance, operability

## Context

ADR-0092 provisions a control-plane cluster and ADR-0093 gives it a chart. Neither gives it an
address, and both say so deliberately: ADR-0092's follow-up records that "ingress, DNS and certificate
issuance for the public control-plane surface" is unmade, and ADR-0093 decision 6 states that
"ingress is a seam this ADR opens and does not close" — the chart renders the public surface behind a
values-selected Ingress or Gateway "with no issuer, no certificate source and no DNS record." The ADR
index carries the row as blocking a first deployment. This ADR closes that row, and only it.

**The deciding owner has directed the shape of the names and the authority for them:** three flat
sibling hostnames — `app-gitfrok.7.solutions`, `auth-gitfrok.7.solutions`,
`agents-gitfrok.7.solutions` — with **Cloudflare authoritative**, in the existing `7.solutions` zone.
This ADR records that direction and works out what follows from it; the rationale is the owner's and
is not invented here. Two consequences follow immediately and are structural rather than
preferential:

- **Delegation is not available.** `NS` delegation acts on a label. These three names are sibling
  labels directly under the apex, so there is no `gitfrok` subtree to delegate — the records live in
  the `7.solutions` zone itself. The Cloud DNS zone ADR-0092 provisions therefore has nothing to
  serve, which is why this ADR amends decision 4 rather than fitting inside it.
- **No credential can be scoped below the zone.** Cloudflare API tokens scope to a zone, and the zone
  is the company apex. Anything holding DNS write for these records holds it for all of
  `7.solutions`. This is the single largest cost in the decision and it drives decisions 7–9.

Four further forces meet here. The first is a fact about shipped code and settles more than any
preference does.

**1. The agent pins our CA to verify the server, so no third party can terminate that door's TLS.**
`platform/agentclient` documents its trust pool exactly: *"Roots is the pinned trust pool: it
verifies the gateway's server certificate AND the client certificates the control plane issues and
rotates"* (`agentclient.go:90–92`), and it is not optional — `cmd/dataplane-app/agent.go` obtains
`GITFROK_AGENT_CA_BUNDLE` through `require()`, so an install without it refuses to start. The agent
does **not** consult system roots for the control plane's server certificate. A publicly trusted
certificate on the agent door — Let's Encrypt, Google-managed, or a Cloudflare edge certificate — is
not a different choice but an **untrusted** one, and it fails at enrolment as a TLS error rather than
as the topology mistake it is. Cloudflare's proxy is therefore unavailable to `agents-gitfrok`
whatever else this ADR decides.

**2. The same door rules out an identity-forwarding proxy, on governance grounds.** Client-cert
verification needs only a CA's public bundle, so an intermediary *could* verify the certificate and
forward the identity in a header — Cloudflare mTLS and GKE Gateway `TrustConfig` both offer that
shape. It is refused for two reasons that outlive the mechanism. A door whose caller identity arrives
as an intermediary's assertion is precisely **SPEC-0002's recorded limit (d)** — the caller-asserted
subject that **SPEC-0043 AC6** exists to close — so adopting it would re-open, on the newest surface,
the limit the previous phase spent a task closing. And it would require keeping the agent CA's trust
bundle current at a second vendor through **SPEC-0044's staged rotation**, putting a rotating custody
artifact outside the custody service ADR-0066 chose to hold it.

**3. Zitadel needs a name of its own.** ADR-0045's login puts Zitadel on this side, and
`ExternalDomain` is baked into what its discovery document advertises (`deploy/dev/zitadel.yaml` sets
`ExternalDomain: zitadel.gitsaas.test`, `ExternalSecure: true`, TLS terminating at the ingress). The
owner's `auth-gitfrok` name is that name; counting two hosts rather than three would have discovered
this during implementation.

**4. Three needed components have no owner, and reserved addresses turn out to be a fourth.**
ADR-0092 decision 4 forbids OpenTofu from creating any Kubernetes object, and ADR-0093 decision 2
limits the chart to three first-party workloads, so an ingress controller, a certificate issuer and a
DNS-record reconciler fall in the gap between the two ADRs. `deploy/dev` answers with an nginx addon
and a machine-local mkcert CA, which ADR-0024 scopes to a laptop. A fourth item joins them once DNS
records are written by hand: GKE hands a Gateway an **ephemeral** global IP and a
`type=LoadBalancer` Service an **ephemeral** regional one, so recreating either changes the address a
static record points at — and for the agent door that silently breaks every enrolment's DNS. A
reserved address is infrastructure, not a workload, so ADR-0092 decision 4 places it in OpenTofu.

## Decision

**1. Three flat records in the existing Cloudflare `7.solutions` zone, as directed.**
`app-gitfrok.7.solutions` (webfrontend → bff), `auth-gitfrok.7.solutions` (Zitadel, per force 3) and
`agents-gitfrok.7.solutions` (the ADR-0017 door). Cloudflare is authoritative. There is no delegation
and no Cloud DNS zone in the path.

**2. The browser and issuer surfaces share one Gateway API listener on GKE's managed controller.**
ADR-0010 §3 already named Gateway API the portable candidate, and GKE's managed controller means
adopting it installs no ingress controller of our own — force 4 loses one ownerless component rather
than housing it. `deploy/dev` keeps nginx under ADR-0024; the dev and production shapes are allowed
to differ here because the dev one is a laptop.

**3. The agent door is a separate L4 address, terminating TLS in the process.**
`agents-gitfrok.7.solutions` resolves to a `Service type=LoadBalancer` in TCP passthrough, and
`controlplane-app` completes the handshake itself. It is never behind decision 2's Gateway and never
behind an identity-forwarding intermediary. The separation is by **hostname and address**, because
nothing below L7 can route on a path.

**4. The agent door's server certificate is issued by the control-plane CA, not a public one.** This
follows force 1 rather than choosing against it: issued from the ADR-0060 CA held in OpenBao
(ADR-0066), carrying `agents-gitfrok.7.solutions` as its name, rotating with the bundle under
SPEC-0044's staged procedure — the same bundle the agent already pins. The agent door is deliberately
not publicly trusted, and nothing about it needs to be.

**5. `agents-gitfrok` is DNS-only, never proxied.** Cloudflare's proxy terminates TLS, which force 1
makes fatal for this record. The record is grey-cloud permanently. This is the decision most exposed
to being undone by a single dashboard click — Cloudflare's dashboard defaults new `A` records to
proxied, while its API and `external-dns` default to DNS-only — so decision 5 is worthless without the
live gate named in the follow-ups. A manifest lint cannot see it; `dig +short` can.

**6. Both public addresses are reserved static IPs provisioned by OpenTofu.** A
`google_compute_global_address` for decision 2's Gateway and a `google_compute_address` for decision
3's Service. Required because the records of decision 1 are static and hand-written: without
reservation, recreating a Service moves the address the record still advertises. Addresses are
infrastructure, so this sits in OpenTofu under ADR-0092 decision 4 — see follow-ups for where.

**7. Certificates for `app-gitfrok` and `auth-gitfrok` come from cert-manager over ACME **HTTP-01**
using the Gateway API solver.** Chosen over DNS-01 for one reason that outweighs its inconvenience:
HTTP-01 proves control through the Gateway that decision 2 already exposes, so **no Cloudflare
credential ever enters the cluster.** Given that the apex zone is the only scope a Cloudflare token
can have, avoiding the credential entirely is worth more than DNS-01's convenience. This requires
cert-manager **≥ 1.15**, where Gateway API support stopped being gated behind a feature flag, with
`config.gatewayAPI.enabled=true` and a listener on port 80. Decision 4 owns the agent door; this
decision covers only the two public-CA hosts.

**8. No `external-dns`.** Three static records do not justify a controller holding DNS write over the
whole company apex — that is the worst blast-radius-to-benefit ratio in the design. The records are
created once, operator-side, and reconciliation of three static names is a human's job.

**9. The Cloudflare Global API Key never enters the cluster, OpenTofu, or a Secret.** The credential
in the operator's working tree is 37 hex characters, which is a **Global API Key** — root on the
entire Cloudflare account, un-scopeable to a zone, authenticating by `X-Auth-Email`/`X-Auth-Key`. It
is an operator credential for the one-time record creation of decision 1 and nothing else, and it
should be rotated. If the DNS-01 fallback is ever taken, its credential is a **purpose-created
zone-scoped API Token** (`Zone:DNS:Edit` on `7.solutions` only), held as a Kubernetes Secret
**referenced by name** on ADR-0093 decision 3's terms — never a value in `values.yaml` and never an
OpenTofu input, so ADR-0092 decision 6 holds.

**10. No Cloudflare provider is added to OpenTofu, and the `dns-zone` unit is retired.** Cloudflare
is a dependency of the *deployment* and not of the provisioned infrastructure, which keeps ADR-0092
decision 6's "no secret is ever an input" literally true. The `dns-zone` module and
`live/prod-cp/dns-zone/` now provision a zone nothing resolves; a dead unit is a defect rather than a
curiosity, so they are removed and `dns_name` in `live/prod-cp/env.hcl` goes moot (follow-up).

**11. The vendor's own data plane (`prod-dp`) publishes nothing under this ADR.** Whether `prod-dp`
exposes an ADR-0094 door is already an open question against ADR-0092/0094. This decision covers the
control plane's public surface only and leaves that unprejudiced.

## Consequences

**Positive:**
- A first real deployment stops being blocked on *this* row. Other rows still block it and are not
  made smaller by this one landing — see follow-ups.
- **`app-gitfrok` and `auth-gitfrok` may be proxied**, so Cloudflare's WAF and DDoS mitigation are
  available to the browser and issuer surfaces. This is the capability a delegated Cloud DNS subtree
  would have given up, and it is the clearest gain of the directed shape.
- Decisions 3 and 4 make force 1's constraint structural: the agent door cannot acquire a
  TLS-terminating intermediary by configuration drift, because it is a different address with a
  different kind of load balancer and a certificate no public issuer could have signed.
- Decision 2 keeps SPEC-0002 limit (d) closed on the newest surface rather than re-opening it.
- Decisions 7, 8 and 9 together mean **no Cloudflare credential of any kind runs in the cluster**,
  despite Cloudflare being authoritative — the outcome ADR-0066 and ADR-0092 decision 6 would want,
  reached without a new custody path.
- Decision 6 turns an ephemeral-IP failure that would have appeared as intermittent enrolment
  breakage into a provisioning fact.

**Negative / costs:**
- **No credential scope below the zone.** Flat sibling names put these records in the company apex,
  so any future automation with DNS write — the DNS-01 fallback, or `external-dns` if decision 8 is
  ever reversed — holds write over all of `7.solutions`, including records nothing here owns. This is
  inherent to the directed naming, not to any choice made around it.
- **Decision 5 is one dashboard click from breaking enrolment**, and the click looks like a security
  improvement to whoever makes it. Mitigated only by the live gate in the follow-ups; unmitigated
  until that exists.
- **Two certificate mechanisms**, by force 1 rather than by taste: ACME for two hosts, the
  control-plane CA for the third. Any gate must know which door it is looking at.
- **HTTP-01 behind a proxied record has a first-issuance trap:** with "Always Use HTTPS" plus Full
  (strict), the `/.well-known/acme-challenge/*` path is redirected to an origin that has no
  certificate yet, and issuance fails (typically a 526). Either issue before enabling the proxy, or
  exempt the challenge path.
- Cloudflare becomes an infrastructure dependency that **no gate and no plan file can see**, because
  decision 10 keeps it out of OpenTofu. The trade is deliberate — no credential in state — but it
  means three production records exist only in a vendor console and in this ADR.
- Three public hostnames and two load balancers where dev has one wildcard on one nginx, so the
  production shape diverges from the dev shape — mildly against ADR-0092 decision 5's "one production
  shape testable against the dev shape".
- GKE's managed Gateway controller is a cloud dependency above the cluster. Acceptable because the
  Gateway *resources* are portable even where the controller is not: an EKS/AKS port swaps the
  controller, not the manifests.
- ACME puts Let's Encrypt in the renewal path of a control plane that ADR-0093 decision 4 already
  describes as sealed-until-unsealed on a cold start.

**Follow-ups:**
- The implementing **spec and task**: the Gateway and its listener on 80, the passthrough Service,
  the cert-manager inputs, the reserved addresses, and the assertion that nothing puts the agent door
  behind an L7 proxy.
- **A live DNS gate for decision 5**, which is the only thing that makes it a property rather than a
  sentence: `dig +short agents-gitfrok.7.solutions` must return decision 6's reserved address, not a
  Cloudflare anycast address. A manifest check cannot substitute.
- **Where the reserved addresses live** — extending the `network` unit or adding an `addresses` unit
  under `live/prod-cp/`. Decision 6 requires them; it does not place them.
- **Retire the Cloud DNS unit** (decision 10): remove `deploy/gcp/modules/dns-zone/` and
  `live/prod-cp/dns-zone/`, drop the README's unit-table row, and moot `dns_name` in `env.hcl`. A
  super-repo commit, separate from this governance one (invariant 23).
- **The `gke-cluster` module does not set `gateway_api_config`** — verified absent from
  `deploy/gcp/modules/gke-cluster/main.tf`. Decision 2 needs the Gateway API CRDs on the cluster.
- **A cert-manager version floor of 1.15** for decision 7, and whether `check-version-floors.sh`
  should carry it.
- **Rotate the Global API Key** (decision 9), and create the zone-scoped token only if the DNS-01
  fallback is taken.
- The operator CIDR for `admin_networks`, and the two `project_id` values: inputs this ADR needs set
  but does not decide.
- Backup and restore, staging, the third-party stateful set's production install, and ADR-0093's
  unimplemented chart remain ADR-0092/0093's open rows, untouched here.

## Alternatives considered

- **Delegating a `gitfrok.7.solutions` subtree to the Cloud DNS zone ADR-0092 provisions.** The
  previous draft of this ADR. It keeps ADR-0092 decision 4 unamended, uses a unit already written and
  already outputting name servers, and — its real advantage — scopes every DNS credential to a
  subtree instead of the company apex. **Rejected by owner decision** in favour of flat sibling names
  with Cloudflare authoritative. Recorded because the scope cost it avoids is now carried as this
  ADR's largest negative, and because it remains the shape to revisit if that cost ever bites.
- **DNS-01 as the primary issuance path**, with a zone-scoped token as a Kubernetes Secret. The plain
  reading of "use Cloudflare", and it avoids the HTTP-01 first-issuance trap. Rejected as primary
  because it puts a credential with write access to the whole company apex into the cluster for a
  benefit HTTP-01 also delivers — but it is the **named fallback** if decision 7's solver or the proxy
  interferes, and decision 9 states its credential terms in advance so the fallback needs no new ADR.
- **`external-dns` managing the records.** Standard practice and genuinely convenient. Rejected under
  decision 8: zone-wide write over the company apex to reconcile three static names.
- **Using the existing Global API Key for cert-manager or `external-dns`.** Rejected outright by
  decision 9: it is account-root, un-scopeable, and cannot be limited to DNS or to one zone. Recorded
  because it is the path of least resistance from the credential that already exists.
- **A publicly trusted certificate on the agent door**, so one issuer covers everything. Rejected by
  force 1 as simply broken against the shipped agent, which pins `GITFROK_AGENT_CA_BUNDLE` and never
  consults system roots. Recorded because it is the obvious simplification and it fails silently at
  enrolment rather than at review.
- **Cloudflare mTLS / GKE Gateway `TrustConfig` verifying client certs and forwarding identity.**
  Rejected by force 2: it re-creates SPEC-0002 limit (d) on the newest surface and moves a rotating
  CA bundle outside ADR-0066's custody.
- **Cloud Armor instead of Cloudflare's edge.** It attaches to the same load balancer decision 2
  selects and would have been the answer under a delegated Cloud DNS zone. Largely redundant here,
  since the directed shape leaves `app-gitfrok` and `auth-gitfrok` free to be proxied — kept as a
  recorded option if the proxy is declined for those hosts.
- **One hostname for all three surfaces, split by port** (443 browser, 8443 agent). Cheaper in records
  and certificates; rejected because it couples the doors' availability to one address and invites
  exactly the misconfiguration decisions 3 and 5 exist to make structurally impossible.
- **Cloudflare Tunnel (`cloudflared`) for the agent door.** Removes the public L4 address. Rejected:
  it terminates TLS at Cloudflare, so force 1 kills it, and it inverts ADR-0011's direction for the
  one connection ADR-0011 specifies.
- **Leaving the seam open and deploying without a public surface** — cluster up, `port-forward` only.
  Rejected as a decision, though a legitimate *interim*: it proves ADR-0093's chart against a real
  cluster without committing to an address. Named so that choosing it is a choice.
