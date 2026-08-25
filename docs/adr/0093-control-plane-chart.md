# ADR-0093: The control plane installs from its own chart, and the chart stops at the workload

- **Status:** Proposed
- **Date:** 2026-08-25
- **Deciders:** platform (requested by the deciding owner)
- **Related:** ADR-0009 (control-plane / data-plane split), ADR-0011 (outbound-only agent),
  ADR-0013 (Helm chart + Operator packaging — the *data-plane* installer), ADR-0024 (Minikube is
  the *dev* environment), ADR-0027 (submodule topology; invariants 21–25), ADR-0034/0035 (image
  pins), ADR-0044/0047 (release signing and registry trust), ADR-0066 (OpenBao custody, Shamir
  unseal), ADR-0092 (GCP is the first-party cloud — this discharges its blocking follow-up)
- **Governs:** operability, G4 change governance

## Context

ADR-0092 provisions a control-plane cluster and then admits nothing can deploy into it. That is the
follow-up this ADR exists to close, and the gap is real rather than clerical: `deploy/dev/*.yaml` is
Minikube-only by ADR-0024, and ADR-0013's chart is the **data-plane** installer — its own
`Chart.yaml` says so, and `scripts/check-byo-chart.sh` makes the claim executable.

That gate matters to the shape of this decision. It asserts the data-plane chart carries **no
secret** and opens **no inbound path** — no Service, no Ingress, no Gateway, nothing with a load
balancer behind it — because ADR-0011's data plane only ever dials out. The control plane is the
inverse on both counts: agents dial *into* it, its web surface is public, and it holds database
credentials, an OIDC client secret and a session key. There is no version of "extend ADR-0013's
chart" that does not consist of deleting that chart's defining property.

The second thing missing is a written partition. `deploy/dev` runs both planes and every backing
service in one namespace, which is correct for a laptop and tells nobody which side each component
belongs to in production. Read from what the binaries actually dial:

| Component | Control plane | Data plane | Evidence |
|---|---|---|---|
| `controlplane-app` | ✓ | | `deploy/dev/controlplane.yaml` |
| `bff` | ✓ | | the SPEC-0021 browser surface |
| `webfrontend` | ✓ | | Astro SSR in front of the BFF |
| `dataplane-app` | | ✓ | ADR-0009 |
| `git-storaged` | | ✓ | repos are the customer's (ADR-0009) |
| Postgres | ✓ | ✓ | both planes set `GITFROK_DATABASE_URL`; separate instances |
| Valkey | ✓ | | `GITFROK_SESSION_VALKEY_ADDR`, BFF sessions only |
| Redpanda | ✓ | ✓ | `platform/bus` is imported by both `cmd/*-app/main.go` |
| OpenBao | ✓ | | the control-plane custody service (ADR-0066) |
| Zitadel | ✓ | | the BFF's login; the data plane only validates tokens |
| SeaweedFS | | ✓ | every `platform/objectstore` consumer is data-plane-side |

Third, a cold start is not one command. `MVP-RUNBOOK.md` records three manual seams the runbook
owns and no chart can absorb: schema migrations (§4), the Zitadel OIDC client (§5), and OpenBao
initialization plus **quorum unseal, "every cold restart, before any consumer starts"** (§6a),
followed by agent-CA provisioning (§6b). ADR-0066 decision 4 rejected cloud-KMS auto-unseal
deliberately, so the quorum seam is a decision, not an omission.

## Decision

**1. A separate chart, `deploy/helm/gitfrok-controlplane/`.** Not an extension of ADR-0013's chart,
for the reason above: that chart's gated properties are the negation of the control plane's
requirements. `check-byo-chart.sh` hardcodes `deploy/helm/gitfrok-dataplane`, so a sibling chart
trips no existing gate and needs no gate rescoping. Location follows ADR-0092 decision 7's
precedent — `deploy/` is tracked directly in the super-repo, and infrastructure is not product
source.

**2. The chart's boundary is the first-party workload.** It renders `controlplane-app`, `bff` and
`webfrontend` — the three images we build, version and release together on the pins
`deploy/dev/versions.env` already records (ADR-0034/0035). It renders **no** stateful service.
Postgres, Valkey, Redpanda, OpenBao and Zitadel are third-party software with their own lifecycles,
quorum procedures and migration ordering; binding them to our application's release cadence would
make every app upgrade a database upgrade. They are **required inputs**: an endpoint and, where
credentials are involved, the name of a Secret that already exists.

**3. No secret, ever, on the same terms as the data-plane chart.** Database credentials, the OIDC
client secret and the session key are `existingSecret` **name references** only. No credential
appears in `values.yaml`, in a chart-authored Secret, or as a literal env value. This carries the
data-plane chart's non-functional requirement across rather than reinventing it.

**4. The chart never promises a running control plane.** `helm install` from cold yields workloads
that cannot serve, because OpenBao is sealed until a human quorum acts (ADR-0066 decision 4,
runbook §6a). The chart models sealed-until-unsealed — the workloads start, report unready, and
converge once custody is available. Bring-up **order** stays the runbook's; nothing here claims to
replace it.

**5. Day-2 is the release pipeline applying the chart, not an Operator.** ADR-0013's Operator earns
its cost across many customer clusters at many versions; the control plane is one cluster we own,
at one version, that we upgrade deliberately. GitOps is **not** the alternative on the table here:
Argo CD appears once in the tree, in ADR-0019, which is Superseded, so a GitOps decision has never
been made rather than having been made and lapsed. Recorded as a follow-up, not assumed.

**6. Ingress is a seam this ADR opens and does not close.** The chart renders the public surface
behind a values-selected Ingress or Gateway, with no issuer, no certificate source and no DNS
record. That leaves ADR-0092's ingress follow-up **open**, and it means this ADR alone does not
unblock a first real deployment: it removes "nothing can deploy the control plane" and leaves
"nothing terminates TLS in front of it". Naming that is the point; folding a half-made ingress
decision in here would hide it.

**7. Vendor-internal, so the customer-facing release machinery does not apply.** The chart is never
published to a customer, so ADR-0044/0047's signed-release and offline-verification rules and
`check-byo-chart.sh` are out of scope for it. Its images remain first-party and pinned; the chart
itself is not a distributed artifact. Said explicitly so the gates' scope stays unambiguous.

## Consequences

**Positive:**
- ADR-0092's blocking follow-up closes, and the cluster it provisions acquires an installer.
- Decision 2 keeps the third-party stateful set on its own upgrade clock, which is also what makes
  the runbook's migration and unseal ordering expressible at all.
- The partition table above becomes the written answer to "which side is this on", which
  `deploy/dev`'s single namespace has been quietly withholding.
- Decision 1 leaves `check-byo-chart.sh` asserting exactly what it was written to assert, instead
  of asserting it about a chart that now has an Ingress in it.

**Negative / costs:**
- A second chart is a second thing to version, and the control plane's three images must move
  together or the chart lies about what it installs.
- Decision 2's honesty is also its cost: the production install of Postgres, Valkey, Redpanda,
  OpenBao and Zitadel is now unowned by any artifact. `deploy/dev` is not it, and nothing else
  exists yet.
- Decision 4 means the control plane has a human in its cold-start path, forever, by ADR-0066's
  choice. Anyone expecting a self-healing region restart should read that decision first.

**A blocking gap this ADR surfaces and does not close.** The BFF is control-plane-side and requires
`GITFROK_REPOSITORY_READER_ADDR` — served by `git-storaged`, which is data-plane-side — and it
**exits** without it (`bff/cmd/bff/main.go`: "without RepositoryReader the browser has no data to
show"). ADR-0011 permits no inbound path to a data plane and states source code never traverses the
agent channel, and no relay, tunnel or reverse-proxy decision exists anywhere in governance.
`deploy/dev` hides this by running both planes in one namespace; ADR-0092 does not, because prod-dp
has a private endpoint and no inbound. So a control plane installed per this ADR can serve login,
admin and billing, and **cannot browse a repository** — not as a defect in the chart, but because
the cross-plane read path has never been decided. It is the largest thing standing between this ADR
and a useful deployment, and it is a new decision, not a task.

**Follow-ups:**
- **The cross-plane repository read path** — the gap above. Blocks the browser surface in any real
  two-cluster deployment.
- **Production install of the third-party stateful set** that decision 2 declares as inputs:
  upstream charts, operators, or promoted manifests. Blocks a first deployment.
- **GitOps**, never decided rather than decided-and-lapsed; decision 5 picks the pipeline for now.
- Ingress, TLS and DNS for the public surface — ADR-0092's row, still open by decision 6.
- Whether the runbook's three manual seams (migrations, OIDC client, unseal) get a production
  procedure distinct from the Minikube one they are written against.

## Alternatives considered

- **Extend ADR-0013's chart** — one artifact, one mental model, and it requires deleting the
  no-inbound and no-secret properties `check-byo-chart.sh` exists to enforce. Rejected: those
  properties are what make the data-plane chart safe to hand a customer.
- **An Operator for the control plane too** — symmetry with ADR-0013, and reconciliation we would
  own anyway. Rejected under decision 5: one cluster at one version does not repay an operator, and
  ADR-0013's exists for fleet scale we do not have on our own side.
- **An umbrella chart with the stateful set as subcharts** — one `helm install` for everything, and
  genuinely tempting. Rejected: it couples Postgres and OpenBao upgrades to an application release,
  and it cannot express the runbook's ordering, where a human unseals custody between two steps.
- **Promote `deploy/dev`'s manifests** — they exist and they work. Rejected: they are Minikube's by
  ADR-0024, single-namespace, single-replica, and carry literal dev credentials.
- **Argo CD / GitOps now** — the right long-term answer and not one this ADR is equipped to make;
  its only appearance in the tree is in a Superseded ADR. Deferred deliberately as a follow-up
  rather than smuggled in as an assumption.
