# ADR-0094: The repository surface is served data-plane-side, behind a door the customer exposes

- **Status:** Accepted
- **Date:** 2026-08-25
- **Deciders:** platform (requested by the deciding owner)
- **Amends:** ADR-0093 decision 2 in part — the component partition moves the repository surface
  to the data plane (ADR-0093 is Accepted and is not edited; ADR-0001)
- **Related:** ADR-0009 (control-plane / data-plane split), ADR-0011 (outbound-only agent),
  ADR-0013 + SPEC-0039 (the BYO data-plane chart), ADR-0017 (agent transport), ADR-0024 (Minikube
  is the *dev* environment), ADR-0045 (OIDC login), ADR-0063/0067 (residency), ADR-0092 (the
  first-party cloud), ADR-0093 (the control-plane chart — this discharges its blocking gap),
  SPEC-0021 (the browser surface)
- **Governs:** G1 isolation, G6 compliance, G7 residency

## Context

ADR-0093 recorded that the BFF is control-plane-side, needs the `RepositoryReader` that
`git-storaged` serves data-plane-side, and exits without it. Investigating that gap found a larger
one underneath it.

**The data plane has no user-facing door in any real install.** The BYO chart renders no Service and
no Ingress — its `deployment.yaml` says the containerPort "exists for kubelet probes alone; nothing
renders a Service for this port", and `check-byo-chart.sh` enforces it. The route that reaches a
data plane, `git.gitsaas.test → dataplane`, exists only in `deploy/dev/ingress.yaml`, which is
Minikube's by ADR-0024. So in a real BYO install today, `git push` is exactly as unreachable as a
file view. This is not a browser problem with a chart-shaped fix; the door itself has never been
decided, and nothing in `governance/docs/` decides it.

Four constraints then narrow the answer to one shape before preference gets a turn.

1. **The control plane must not dial a data plane.** ADR-0011 in words, and
   `internal/arch.CheckNoDataPlaneDial` as an enforced gate walking `cmd/controlplane-app` and its
   imports. The BFF's existing dial survives only because `bff/` is a separate Go module outside
   that walk — the current wiring violates the intended invariant and escapes the gate
   *structurally*, not because anyone decided it was allowed.
2. **Source code must not traverse the vendor.** ADR-0011 states source never crosses the agent
   channel. It is also what makes G7 residency and G1 isolation true claims rather than aspirations:
   a vendor process that renders a file has that file.
3. **The browser must not hold a data-plane address.** Five approved specs commit their surfaces to
   working "with no client script", and SPEC-0049 states the property directly — "the browser holds
   no BFF address". A browser that fetches repository content from a second origin contradicts all
   five.
4. **The data plane already authenticates end users.** Not as something to build: `dataplane-app`
   wires a full OIDC login — issuer, client, redirect, role claim, tenant mapping (ADR-0045) — plus
   PATs and SSH keys, and answers to the same PDP as everything else. It has the identity machinery
   a repository surface needs, and the control plane's session is not what authorizes a repository
   read.

Constraints 2 and 3 together eliminate every arrangement in which the vendor's web tier renders
repository content, and constraint 1 eliminates every arrangement in which it fetches it. Today's
tree does both: `webfrontend/src/pages/repos/[repositoryID]/file/[revision]/[...path].astro` calls
`await file(Astro.request, …)` in page frontmatter — server-side, during SSR — so file bytes cross
two vendor-hosted processes on their way to a browser.

**The reconciliation this ADR must make.** SPEC-0039's out-of-scope names "any inbound path into the
customer's cluster, in any form, for any reason". That clause governs what **the vendor's chart
opens** — conformance row 12's tripwire counts inbound connections *from vendor components*, and the
Git front door has always existed in the binary. It has never governed what a **customer exposes of
their own cluster to their own users**. Read the other way, the clause forbids `git push`, which no
one intends.

## Decision

**1. The data plane's user door is the customer's to expose, and the chart still never opens it.**
The chart renders no Service and no Ingress; `check-byo-chart.sh` keeps asserting exactly that. What
changes is that the door becomes a **documented, supported install step the customer performs** in
their own cluster, with published route and TLS requirements. The vendor opens nothing and reaches
nothing.

**2. That one door serves both Git and the repository surface.** Git smart HTTP and LFS reach it
today by design; the repository browse, search, diff and blame surfaces join them. One door, one
TLS terminus, one authorization path — not a second endpoint per capability.

**3. The repository surface moves data-plane-side.** A `bff` + `webfrontend` instance runs on the
data plane and serves the repository routes: tree, file, diff, history, blame, code search, and the
merge-request views that render diffs. It reads `git-storaged` in-cluster, exactly as
`dataplane-app` already does. This **amends ADR-0093's partition**, which placed both components
control-plane-side; that table was read from `deploy/dev`, where one namespace makes the question
invisible.

**4. The control plane keeps every surface that is metadata, and renders no repository content.**
Identity and login, billing and usage, the fleet view, policy authoring, audit and evidence packs,
auditor grants, notifications, admin. Its web tier keeps SSR and keeps working with no client
script, because it never needs a byte from a repository to render any of it.

**5. Route partition, not two products.** `bff` and `webfrontend` remain one codebase each, deployed
twice with different route sets enabled. A control-plane deployment refuses to start with a
`RepositoryReader` address configured; a data-plane deployment requires one. The refusal is the
enforcement: a misconfigured deployment fails at boot rather than serving a route it should not
have.

**6. Cross-plane navigation is by URL, never by proxy.** A control-plane page that links to a
repository links to the customer's data-plane door. The control plane stores that door's base URL as
part of the enrolment record it already keeps, and renders links from it. No request is forwarded,
tunnelled or relayed, and ADR-0011 stands **unamended** — which is the property that makes this
shape worth its cost.

**7. Enforcement reaches the BFF.** The gate that proves decision 1 today walks only the backend's
control-plane trees. It must also assert that a control-plane-configured `bff` has no data-plane
dial, or the invariant remains true by accident of repository layout.

## Consequences

**Positive:**
- Source code never enters a vendor-hosted process. G7 residency and G1 isolation become properties
  of the topology rather than promises about behaviour, and the same is true for a customer's own
  audit of where their code has been.
- ADR-0011 survives untouched, and so does the fitness function behind it. Nothing here needs an
  invariant relaxed.
- The no-client-script property is preserved on both planes, because each web tier renders from a
  service it can reach in-cluster.
- `git push` acquires a decided door, which it did not have. The gap this ADR was opened for was
  never only about browsing.
- The data plane's existing OIDC login, PATs, roles and PDP stop being half-used machinery.

**Negative / costs:**
- The web tier deploys twice, and the route partition is a new failure mode: a deployment with the
  wrong route set is a deployment serving the wrong plane's surface. Decision 5 makes it a boot
  refusal rather than a runtime surprise, which is mitigation, not absence.
- A customer must expose a door on their own cluster before their developers can use the product at
  all. That is real installation friction and a real conversation with their security team — and it
  is the honest price of source never leaving their cloud.
- Two web surfaces means two navigation shells, and a user crosses a domain boundary moving from
  billing to a file view. Decision 6 keeps that crossing a link rather than a proxy, but the seam is
  visible to the user.
- SPEC-0021 is written for a control-plane BFF shaping `RepositoryReader`. Its deployment premise
  changes even though its request and response shapes do not; it needs amending, and so do the
  specs of every surface decision 3 moves.

**Follow-ups:**
- Amend SPEC-0021 and the repository-surface specs for the data-plane premise, and file the
  implementing task. Nothing moves in `bff/` or `webfrontend/` until that lands.
- The door's published contract: routes, TLS requirements, and what a customer must satisfy for the
  install to be supported. This is what makes decision 1 a step rather than an instruction to
  improvise.
- Extend the no-data-plane-dial gate to the `bff` repo (decision 7).
- Where the data plane's door URL lives on the enrolment record, and what the control plane does
  when it is absent — a tenant with no exposed door has a billing surface and no repository surface,
  and that state must render as itself rather than as an error.
- Whether the control plane's own reference data plane (ADR-0092's vendor-as-first-customer) exposes
  its door publicly or only to the operator network, given prod-dp's private endpoint.

## Alternatives considered

- **Relay repository reads over the agent channel.** One door, no customer ingress, and the
  control-plane BFF keeps working unchanged. Rejected twice over: ADR-0011 states source never
  traverses that channel, and `CheckNoDataPlaneDial` is an enforced gate, so this is not a design
  choice but a supersession of an invariant with a fitness function behind it. It would also make
  the vendor a transit path for every customer's source, which is the thing BYOC is sold as not
  being.
- **Browser fetches repository content directly from the data-plane door**, control-plane shell
  around it. Attractive: one web deployment, no route partition. Rejected under constraint 3 — five
  approved specs commit to working with no client script, and SPEC-0049 states that the browser
  holds no service address. This would reverse a property asserted across the whole surface, which
  is its own ADR if anyone wants it.
- **Keep the status quo: the control-plane BFF dials `git-storaged`.** It works in `deploy/dev` and
  it is what the code does today. Rejected: it survives only because `bff/` sits outside the gate's
  walk, it puts source through two vendor processes, and it requires an inbound path into the
  customer's cluster for the vendor — the one thing SPEC-0039 forbids without ambiguity.
- **Move the entire web surface data-plane-side.** No route partition, no second deployment, one
  shell. Rejected: billing, fleet and audit are multi-tenant control-plane data, and a tenant
  between data planes — or evaluating without one — would have no product at all. It also puts the
  vendor's own admin surface inside a customer's cluster.
- **Serve the repository surface from the control plane against a customer-run read replica of
  `git-storaged`.** Rejected: replicating repository content to the vendor is the residency
  violation in a different costume, and it doubles storage to achieve it.
