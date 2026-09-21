# ADR-0096: Kustomize is the only installer technology, and Helm leaves the tree

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (directed by the deciding owner, restated when this ADR was scoped to one plane)
- **Amends:**
  - **ADR-0093 decision 1 in whole, decision 5 in part** — the control-plane installer is a Kustomize
    base with per-environment overlays at `deploy/k8s/controlplane/`, not a Helm chart at
    `deploy/helm/gitfrok-controlplane/`; day-2 applies an overlay.
  - **ADR-0013's packaging half** — the BYO data-plane installer becomes
    `deploy/k8s/dataplane/`, distributed as a signed bundle (decision 6). **ADR-0013's Operator
    survives unchanged**: it still reconciles, still owns day-2 across many customer clusters, and
    now applies a verified overlay instead of a chart.
  - Both ADRs are Accepted and are **not edited** (ADR-0001). ADR-0093 decisions 2, 3, 4 and 7 carry
    over verbatim as decision 4 below, because they are properties of the installer's boundary and
    not of its templating engine.
- **Related:** ADR-0024 (Minikube is the *dev* environment — `deploy/dev/*.yaml` is already plain
  manifests and is untouched), ADR-0034/0035 (image pins, first-party images), ADR-0044 (signed
  releases, verify-before-apply), ADR-0047 (registry trust, offline verification), ADR-0066 (OpenBao
  custody — the human in the cold-start path), ADR-0092 (GCP is the first-party cloud; decision 4's
  "OpenTofu never provisions a workload" draws the line this installer sits on the other side of),
  ADR-0094 (the repository surface is data-plane-side), ADR-0095 (the public surface: a Gateway, an L4
  agent door, reserved addresses — what the control-plane overlay must render), SPEC-0039 (the BYO
  chart's acceptance criteria — **partly invalidated, see decision 7**), SPEC-0045 (multi-cluster BYO
  readiness and its conformance matrix)
- **Governs:** G4 change governance, operability

## Context

Two installers exist in governance and exactly one of them exists in the tree. ADR-0013 decided a
Helm chart plus an Operator for the **customer's** data plane, and that chart is real, signed,
gated and proven. ADR-0093 decided a second Helm chart for the **vendor's** control plane, and that
one **was never built** — `deploy/helm/` holds only `gitfrok-dataplane`, and no spec and no task ever
referenced ADR-0093.

The deciding owner has directed **Kustomize, and never Helm.** The direction was given once scoped to
the control plane's spec and task, then restated without that scope, so it is recorded here as what it
says: Kustomize is the only installer technology this tree uses, and Helm leaves it. This ADR records
that direction and works out what follows. The rationale is the owner's and is not invented here; what
follows is not all cheap, and the expensive parts are named rather than smoothed.

The two planes arrive at this decision from opposite positions, and conflating them is how the cost
gets hidden.

**The control plane is the easy half, and three things already argued for it.** ADR-0093 decision 7
states the control-plane artifact is "vendor-internal", "never published to a customer" and "not a
distributed artifact" — which is why ADR-0044/0047 and `check-byo-chart.sh` are out of scope for it.
That sentence removes Helm's strongest claim, which is packaging and versioning for *other people*: a
`values.yaml` API, a chart repository, a chart version independent of its images. None of it was being
used. ADR-0093 decision 5 had already reasoned the same way when it rejected an Operator here — "the
control plane is one cluster we own, at one version, that we upgrade deliberately" — and an installer
parameterized by one environment needs a base and an overlay, not a values API. And because the chart
was never built, the engine is being chosen rather than changed. This is the cheapest moment this half
of the decision will ever have.

**The data plane is the expensive half, and none of that reasoning transfers.** That chart *is*
distributed. Customers install it at versions we do not choose. It is signed under ADR-0044 and
verified before anything is applied. `scripts/check-byo-chart.sh` asserts eight things about it, and
its `helm lint` / `helm template` assertions were **NOT RUN** for most of the chart's life, then
finally executed green on a helm-equipped lane on **2026-08-21** — recorded on conformance-matrix rows
11 and 14 as the T-0042 board #23 landing item. Converting the chart voids that evidence. The matrix's
own rule is that a blurred row is a failed row, so those rows do not keep their green by inheritance;
they return to "not run" with a cause and must be re-earned against whatever renders the manifests
next.

And Kustomize has no package. Helm's chart is a versioned, signable, fetchable artifact that
`helm install` consumes in one command. `kubectl apply -k` consumes a directory. A customer-facing
installer therefore needs a distribution answer that Helm supplied for free, and ADR-0044's
verify-before-apply rule means that answer has to be signable. Decision 6 is that answer, and it is
the single most load-bearing decision in this ADR.

## Decision

**1. Kustomize is the only installer technology in this tree.** No Helm chart, no Helm template, no
`helm` invocation in any gate, and no Helm on the required toolchain. Kustomize is `kubectl`'s
built-in, so the control-plane and data-plane paths acquire no new tool.

**2. The control plane installs from `deploy/k8s/controlplane/`.** `base/` renders the three
first-party workloads; `overlays/prod-cp/` carries what ADR-0092's control-plane environment needs,
including ADR-0095's Gateway, the L4 agent door, and their reserved addresses. There is no
`deploy/helm/gitfrok-controlplane/` and never was.

**3. The data plane installs from `deploy/k8s/dataplane/`,** replacing
`deploy/helm/gitfrok-dataplane/`. Every property `check-byo-chart.sh` asserts is a property of the
rendered output, not of Helm, and must survive the move: values carry no token field, the installer
authors no Secret, the token reaches the container only by `secretKeyRef`, the `DataPlane` CR schema
is reference-only with a credential-free status, **no inbound path is opened** (no Service, Ingress,
Gateway, LoadBalancer, NodePort or hostPort), the agent wiring opens no listener, and the reconcile
contract is named rather than implied.

**4. ADR-0093's boundary decisions carry over verbatim, because they are not about Helm.** Restated
so this ADR reads alone:
- **The control-plane boundary is the first-party workload** — `controlplane-app`, `bff`,
  `webfrontend`. No Postgres, Valkey, Redpanda, OpenBao or Zitadel; they are third-party software on
  their own lifecycles and remain **required inputs**: an endpoint, and where credentials are involved
  the **name** of a Secret that already exists.
- **No secret, ever**, on either plane. Credentials, the OIDC client secret and the session key are
  name references consumed through `secretKeyRef`. Under Kustomize this needs active defence rather
  than restraint — decision 5.
- **The installer never promises a running control plane.** OpenBao is sealed until a human quorum
  acts (ADR-0066 decision 4); workloads start, report unready, converge once custody exists. Bring-up
  order stays the runbook's.
- **The control-plane installer stays vendor-internal**, so ADR-0044/0047 remain out of scope *for it*.
  The data-plane installer is the opposite and decision 6 governs it.

**5. `secretGenerator` is forbidden on both planes, and a gate enforces it.** This is the one hazard
the engine swap creates rather than inherits. Helm made "author no Secret" easy to keep: writing one
took deliberate effort. Kustomize ships `secretGenerator` as the ergonomic front door to exactly that
— a literal or an `.env` file becoming a Secret in rendered output — and every tutorial teaches it.
So the prohibition becomes executable: the gates render each overlay and fail if the output contains a
`Secret` this tree authored, or if any `secretGenerator` appears in any `kustomization.yaml`.
`envFrom` / `secretKeyRef` against a pre-existing Secret name is the only permitted shape.

**6. A customer installs the data plane from a signed bundle of rendered manifests, and ADR-0013's
Operator applies it.** This is Helm's packaging replaced rather than dropped:
- The release artifact is the **rendered output** of `deploy/k8s/dataplane/` at a pinned revision with
  digest-pinned images — a flat, reviewable set of manifests with no templating language left in it.
- It is **signed and distributed on ADR-0044's existing terms**, in the shape `deploy/releases/`
  already uses, and **verified before anything is applied**. `scripts/check-signed-releases.sh` keeps
  its job; only the payload's format changes.
- **ADR-0013's Operator is unchanged and is now the install ergonomics**: it reconciles the verified
  bundle, so the customer's one command stays one command and does not become
  `kubectl apply -k` against a directory they fetched themselves.
- Rendering at release time rather than at install time is a **gain** against ADR-0044: what is signed
  is what is applied, with no template evaluated on the customer's cluster after verification.

**7. The evidence this invalidates is named, and returns to "not run" rather than inheriting green.**
`check-byo-chart.sh` sections 0–7 are grep assertions over authored files and port with their intent
intact; **section 8 — `helm lint` plus two `helm template` renders — has no meaning after this ADR.**
Conformance-matrix **rows 11 and 14** cite that section and were proven green on 2026-08-21; they
revert to "not run" with this ADR as the stated cause, per the matrix's own honesty rule, and are
re-earned against `kubectl kustomize`. **SPEC-0039 AC1/AC2's helm-rendered clauses require amendment**,
which is a governance change and not a task's to assume. T-0042 inherits the re-earning.

**8. Day-2 applies an overlay; rollback is a pinned revision.** ADR-0093 decision 5's choice of the
release pipeline over an Operator for the *control plane* is unchanged. What changes is that there is
no `helm rollback`, because Kustomize keeps no release history in the cluster: rolling back means
re-applying at the previous revision with the previous digests. The applied revision and digests must
therefore be recorded per apply — the pipeline's job, named as a follow-up. GitOps remains undecided
(ADR-0093 decision 5's follow-up); Kustomize makes taking that decision later easier, and does not
take it here.

**9. Image pins are the `images:` transformer, by digest.** ADR-0034/0035 require first-party images to
be pinned; `images:` is one declarative entry per image, which improves on a values file's indirection.
ADR-0035's open follow-up — `deploy/dev` pins by tag, not digest — is not closed here, but both new
installers start digest-pinned rather than inheriting the gap.

**10. `deploy/dev` is untouched.** It is already plain manifests applied with `kubectl`, owned by
ADR-0024, and contains no Helm — so "Helm leaves the tree" costs it nothing. Whether it should
eventually share the `base/` of decision 2 is **not decided here**.

## Consequences

**Positive:**
- One installer technology across both planes, which is what the direction asked for and what removes
  the "two things to know" cost ADR-0093's second chart would have added.
- For the control plane the engine is chosen before anything is built: nothing is migrated, no chart is
  thrown away, and ADR-0093's unimplemented-chart row leaves the register as this installer's row.
- Decision 6 makes ADR-0044 **stronger**: the signed artifact becomes the exact manifests that get
  applied, instead of a chart whose templates are evaluated on the customer's cluster after the
  signature was checked.
- Rendered output is reviewable as plain manifests — no `tpl`, no chart-version skew against the images
  installed.
- Decision 5 converts a convention into a gate, and it catches the specific mistake this engine makes
  easy. That is a better position than ADR-0093's, where the same rule rested on Helm being
  inconvenient.
- Decision 9 makes digest pinning the default shape rather than a discipline.
- No new toolchain: Kustomize is in `kubectl`, so `check-version-floors.sh` gains nothing to gate.

**Negative / costs:**
- **Conformance evidence is destroyed and must be re-earned** (decision 7). Rows 11 and 14 were the
  T-0042 board #23 landing item, green since 2026-08-21 after being NOT RUN for most of the chart's
  life. This ADR sends them back. That is the largest cost here and it is a real regression in proof,
  not a bookkeeping change.
- **SPEC-0039 requires amendment**, so an Approved spec with Implemented tasks acquires an open edit —
  the kind of churn ADR-0001's process exists to make visible rather than cheap.
- **No release history in the cluster.** `helm rollback` told you what was installed and could undo it
  without the source. Decision 8's answer needs the revision and digests recorded durably; skip that
  and rollback becomes archaeology.
- **No `required`.** Helm could fail a render on a missing input. Kustomize renders a Deployment with
  an empty env value without complaint, so ADR-0093 decision 2's "required inputs" need the gate to
  stay required — folded into decision 5's gate rather than left as intention.
- **`secretGenerator` is a live hazard**, not hypothetical: it is the idiomatic Kustomize answer to
  "how do I get a Secret in".
- **The customer-facing ergonomics now depend entirely on the Operator.** Helm gave a customer one
  familiar command against a fetchable versioned artifact; decision 6 replaces it with a signed bundle
  plus ADR-0013's Operator. If that Operator is ever unavailable for an install path, the fallback is
  more steps than `helm install` was, and the BYO install story gets worse rather than better.
- **Overlay proliferation** is Kustomize's failure mode the way values sprawl is Helm's. With ADR-0092
  already shaping `live/` for staging, this wants a stated rule about what an overlay may vary before
  the second one exists.
- The tree's Helm references — ADR-0013, ADR-0021/0024, ADR-0035, ADR-0060, ADR-0065, ADR-0092,
  ADR-0093, SPEC-0045, the phase-3 plan, five task files, the roadmap and the tasks README — become
  historical rather than current. None are edited (ADR-0001); the index says which decision now
  governs.

**Follow-ups:**
- **SPEC-0067 + T-0084 — the control-plane installer.** Filed with this ADR.
- **SPEC-0068 + T-0085 — the data-plane conversion**, which is a separate unit of work and cannot ride
  the control-plane task: it amends SPEC-0039, rewrites the gate, re-earns the matrix rows and changes
  the release payload's format. **Required by decision 3 and not filed here.**
- **`scripts/check-controlplane-kustomize.sh`** — render the overlay; fail on an authored `Secret` or
  any `secretGenerator`; assert every first-party image is digest-pinned; assert ADR-0095's agent door
  stays an L4 `LoadBalancer` with no L7 route or annotation.
- **`scripts/check-byo-kustomize.sh`** — sections 0–7 of `check-byo-chart.sh` ported with their intent
  intact, plus a `kubectl kustomize` render replacing section 8. The no-inbound tripwire and the token
  sentinel are the two that must not weaken in translation.
- **Conformance-matrix rows 11 and 14 back to "not run"** with this ADR as the cause, and T-0042's
  scope updated.
- **Recording the applied revision and digests per apply** (decision 8), without which rollback has no
  source of truth.
- A stated rule for what an overlay may vary, before a second overlay exists.
- Whether `deploy/dev` converges on decision 2's base — explicitly **not** decided here.
- GitOps, still undecided, inherited from ADR-0093 decision 5.
- Unchanged and still blocking a first deployment: the production install of the third-party stateful
  set (ADR-0093 decision 2's row), and the runbook's three cold-start seams.

## Alternatives considered

- **Helm on both planes, as ADR-0013 and ADR-0093 decided.** The status quo, half-built. One
  technology, `required` and `helm rollback` for free, a fetchable versioned artifact customers know,
  and conformance rows that stay green. **Rejected by owner decision**, restated when this ADR was
  first scoped to one plane. Recorded with what rejecting it costs — every negative above is one of
  Helm's advantages — so that reversing this means reading one section rather than re-deriving the
  trade.
- **Kustomize for the control plane only, Helm retained for the data plane.** This ADR's first draft,
  and the cheaper decision by a wide margin: it takes the half where the chart was never built and
  leaves untouched the half that is distributed, signed, gated and proven. **Rejected by the owner's
  restatement.** Recorded because it is the shape to return to if decision 7's re-earning or decision
  6's ergonomics prove worse than expected — reverting to it costs nothing already spent on the
  control plane.
- **Helm for packaging with Kustomize post-rendering** (`helm template | kubectl kustomize`, or Helm's
  post-renderer). Keeps chart versioning, adds overlay patching. Rejected: it is both engines, paying
  both complexities, and the direction is no Helm.
- **Shipping the data plane as a raw `kubectl apply -k` against a fetched directory, with no bundle.**
  The simplest reading of "Kustomize only". Rejected because ADR-0044 requires verify-before-apply and
  a directory a customer fetched is not a signed artifact — it would trade a governance property for
  convenience.
- **Plain `kubectl apply -f` static manifests, as `deploy/dev` does.** Simplest, and proven in dev.
  Rejected: ADR-0092 shapes `live/` for a staging environment, and two environments with no overlay
  mechanism is where copy-pasted manifests come from — the reasoning ADR-0092 used against console
  clicking.
- **An Operator for the control plane too.** Already rejected by ADR-0093 decision 5 for a reason this
  ADR does not disturb: one cluster at one version does not amortize an Operator.
- **Converting `deploy/dev` in the same change**, so dev and production share a base. Genuinely
  attractive — the only thing that makes ADR-0092 decision 5's "one production shape testable against
  the dev shape" literally true. Rejected as scope, not as an idea: ADR-0024 owns `deploy/dev`, and
  folding it in would hide it.
