# T-0084: The control-plane Kustomize installer

- **Status:** In progress (2026-09-22) — **10 of 12 criteria met; AC5 and AC9 are not, and neither
  is met by trying harder.** The installer renders, the gate is wired into `make verify` and proven
  failable by seven fixtures. AC5 has no inputs (no published digest exists for the three
  first-party images) and AC9 stops at this task's own instruction (the binary serves no readiness
  signal that distinguishes a sealed OpenBao from an unreachable one). Both are recorded below
  rather than waived
- **Phase / Epic:** first control-plane deployment (ADR-0092 → 0093 → 0095/0096). **No epic yet** —
  the backlog has no epic for the vendor-run control plane; filing one is part of accepting ADR-0096.
- **Repo(s):** **super-repo** only (`deploy/k8s/controlplane/`, `scripts/check-controlplane-kustomize.sh`).
  Governance carries this task and its spec; no `backend`, `bff` or `webfrontend` change is in scope —
  if AC9's readiness probe turns out not to exist, that is backend work and a separate task, not a
  quiet addition here (invariant 23: one commit never spans two submodules).
- **Spec:** docs/specs/SPEC-0067-control-plane-kustomize-installer.md (Approved 2026-09-22 — RED may begin)
- **ADRs:** 0096 (Accepted — Kustomize is the installer), 0095 (Accepted — the public surface this
  overlay renders), 0093 (the boundary decisions carried over), 0092, 0024, 0034/0035, 0066, 0094
- **Owner:** unassigned

## Goal

Build the artifact ADR-0093 decided and never produced, with the engine ADR-0096 directs: a Kustomize
base plus a `prod-cp` overlay that renders the three first-party control-plane workloads and ADR-0095's
public surface, with a build-blocking gate that makes its properties executable rather than intended.

**What this does not do, stated first because the distance is easy to misread:** it does not produce a
serving control plane. ADR-0093 decision 2's third-party stateful set — Postgres, Valkey, Redpanda,
OpenBao, Zitadel — is unowned by any artifact and independently blocks a first deployment, and
ADR-0066 keeps a human in the cold-start path by decision. This task makes the first-party half
installable. Done here means the render and the gate are right, not that anything is running.

## Acceptance criteria (test-first)

All twelve are SPEC-0067's, carried verbatim rather than paraphrased:

- [ ] AC1 the overlay renders exactly the three first-party workloads, no fourth
- [ ] AC2 no Postgres/Valkey/Redpanda/OpenBao/Zitadel workload in the render — endpoints only
- [ ] AC3 no `secretGenerator` anywhere under `deploy/k8s/`, no tree-authored `Secret` in the render,
      gate mutation-tested
- [ ] AC4 every credential arrives by `secretKeyRef`/`envFrom.secretRef` naming a pre-existing Secret
- [ ] AC5 every first-party image pinned by digest through `images:`
- [ ] AC6 the agent door is an L4 `LoadBalancer` with no L7 route or annotation, gate mutation-tested
- [ ] AC7 browser and issuer hosts behind a Gateway listener, including :80 for ACME HTTP-01
- [ ] AC8 both public addresses referenced as reserved, never ephemeral
- [ ] AC9 sealed-until-unsealed: workloads start and report unready, never crash-loop or block forever
- [ ] AC10 `check-controlplane-kustomize.sh` is failable — non-zero on each negative fixture, zero on
      the tree as shipped
- [ ] AC11 `base/` renders alone; the overlay varies only hostnames, addresses, replicas, digests
- [ ] AC12 no helm chart, `values.yaml` or `helm` invocation under `deploy/k8s/controlplane/`, and
      `deploy/helm/gitfrok-controlplane/` does not exist

## Tests to write first

RED before the base exists, in this order — the gate first, because AC10 is the criterion that makes
the other assertions worth anything:

- **`scripts/check-controlplane-kustomize.sh` with negative fixtures** under `scripts/testdata/`: an
  overlay with a `secretGenerator`, one with a tag-pinned image, one with an `HTTPRoute` attached to
  the agent-door Service, one requesting an ephemeral address. Each must exit non-zero, and the shipped
  tree must exit zero. This is AC10, and it is the first thing written.
- **Render assertions** (AC1, AC2, AC4, AC5, AC7, AC11) over `kubectl kustomize` output — parsed, not
  grepped, so that a YAML comment cannot satisfy or break an assertion.
- **Determinism** (SPEC-0067 non-functional): two renders at one revision are byte-identical.
- **AC12** as a path and content assertion, so "never Helm" is checked rather than remembered.
- **AC9** last and only after open question 2 is settled: read whether `controlplane-app` has a probe
  that distinguishes a sealed OpenBao from an unreachable one. **If it does not, stop** — that is
  backend work and a separate task. Do not add a probe to a manifest that the binary does not honour.

Follow `../process/agentic-sdlc.md`; shell work obeys `check-shell-portability.sh` (the macOS lane,
SPEC-0014).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (super-repo): `make verify`, `check-shell-portability.sh`, and the new
`check-controlplane-kustomize.sh` green with its fixtures; `check-byo-chart.sh` **unmodified and still
green**, since the data-plane chart is out of scope here and ADR-0096 decision 3's conversion is
T-0085's (see Notes). `check-docs.sh` green in governance for the spec's status transition.

## Exit record (2026-09-22)

**Built:** `deploy/k8s/controlplane/base/` (8 resources: a ServiceAccount, a custody-snapshot claim,
three Deployments, three Services) and `overlays/prod-cp/` (the ADR-0095 Gateway with its `:443`
and ACME `:80` listeners, two HTTPRoutes, the L4 agent door, and the hostname patch).
`scripts/check-controlplane-kustomize.sh` plus `scripts/test-controlplane-kustomize.sh`, both wired
into `make verify`.

**Met:** AC1, AC2, AC3, AC4, AC6, AC7, AC8, AC10, AC11, AC12 — asserted by the gate, and the gate
is proven to refuse each defect it claims to catch.

**AC5 — NOT MET, no inputs exist.** The criterion wants `@sha256:` digests. `deploy/dev/versions.env`
pins `controlplane-app`, `bff` and `webfrontend` by tag and records that they are "never published
to an external registry in this environment" — `dev-up.sh` builds them into the Minikube node — and
`deploy/releases/` carries signed digests for `dataplane-app` and `operator-app` only. There is
nothing to pin to. The gate reports AC5 as **NOT RUN with that cause on its own output line** rather
than passing quietly, in `check-byo-chart.sh`'s idiom. It closes when the three images are first
published to the Artifact Registry `prod-cp` provisions.

**AC9 — STOPPED, by this task's own instruction.** The test plan said: read whether
`controlplane-app` has a probe distinguishing a sealed OpenBao from an unreachable one, and **if it
does not, stop — that is backend work and a separate task. Do not add a probe to a manifest that the
binary does not honour.** It does not: `deploy/dev/controlplane.yaml` serves `/healthz` for both
liveness and readiness. So the base carries `/healthz` with the limit written beside it, and the
Deployment will report Ready while custody is sealed and the agent door is refusing. **A backend
task for a custody-aware readiness endpoint is the follow-up**, and it is not filed by this task.

**The BFF cannot start as rendered, and that is ADR-0011 holding rather than a defect here.**
`bff/cmd/bff/main.go` requires `GITFROK_REPOSITORY_READER_ADDR` and exits without it; the reader is
`git-storaged`, which is data-plane-side. Setting it to a data-plane address would make a
control-plane process dial a data plane, which ADR-0011 forbids and `CheckNoDataPlaneDial` asserts;
omitting it exits the binary. ADR-0093 surfaced this as its blocking gap and ADR-0094 settled it in
principle — a control-plane BFF serves no repository content, so it should need no reader — but the
code has not caught up, and ADR-0094's register row says nothing moves in `bff/` until SPEC-0021 is
amended. So the address comes from a ConfigMap this installer does **not** create: an operator who
supplies one is making the ADR-0011 call visibly rather than inheriting it from a manifest.

**Three false positives in the gate's first version, caught by writing the fixtures rather than by
review** — recorded because each is a general trap:
- The `secretGenerator` check was a `grep`, and the gate's **own comment** saying "no
  secretGenerator" tripped it. It now parses the kustomization as YAML.
- `GITFROK_SESSION_VALKEY_ADDR` was flagged as a credential because "KEY" lives inside "VALKEY".
- `GITFROK_CUSTODY_KEY_NAME` was flagged because a key's *name* is not a key.
Credential detection is now whole-word on underscore-split tokens, with reference suffixes
(`_NAME`, `_FILE`, `_ADDR`, `_MOUNT`, `_ROLE`, `_ID`, `_PATH`) excluded and `GITFROK_DATABASE_URL`
named explicitly, since it carries a password without containing a credential word.

**Production differs from dev in two ways worth naming.** The dev manifest runs a busybox TCP proxy
sidecar so the custody adapter can reach OpenBao over plain HTTP on loopback; production terminates
TLS, so neither the sidecar nor `GITFROK_CUSTODY_ALLOW_LOOPBACK_HTTP` appears here — carrying a dev
relaxation into production is how it becomes permanent. And dev inlines `GITFROK_DATABASE_URL` with
its password; AC4 forbids that, so it is a `secretKeyRef`.

**Not applied anywhere.** No cluster exists: the GKE apply refused both clusters on an unrelated
module bug (fixed at super-repo `be8ef63`) and the re-apply has not run. Every criterion above is
proven by rendering, which is what let this task proceed with no cluster at all.

## Notes / open questions

**Unblocked 2026-09-22, and never lane-blocked.** Unlike T-0042, nothing here needs a cluster: the
whole of SPEC-0067 is provable by rendering, which is why this task could be written before any
cluster exists. Both ADRs were Accepted as written, so nothing this task's criteria restate moved.

**Two prerequisites this task cannot satisfy itself:**

- **Reserved addresses have no unit.** ADR-0095 decision 6 requires a
  `google_compute_global_address` and a `google_compute_address`; ADR-0095's follow-ups note it does
  not place them. AC8 can only assert the overlay references an address and never requests an
  ephemeral one until that OpenTofu unit exists. Filing it is a separate super-repo task.
- **`gateway_api_config` is absent** from `deploy/gcp/modules/gke-cluster/main.tf` (verified). AC7's
  Gateway renders regardless, but it cannot be *applied* to a cluster without the CRDs, so the
  cluster-lane demonstration of this task inherits that gap.

**The data-plane conversion is not this task.** ADR-0096 decision 3 converts
`deploy/helm/gitfrok-dataplane` too, and decision 7 records what that destroys: conformance-matrix
rows 11 and 14 go back to "not run", `check-byo-chart.sh` section 8 loses its meaning, SPEC-0039
needs amending, and the release payload's format changes. That is **SPEC-0068 / T-0085**, unfiled, and
it must not be folded in here — it is a different artifact, a different gate, a different spec to
amend, and it has a customer on the other end of it.

**Nothing under `deploy/dev` changes** (ADR-0096 decision 10). It is already plain manifests and
contains no Helm, so "Helm leaves the tree" costs it nothing. Whether it should share this base is
explicitly undecided.
