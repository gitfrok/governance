# T-0084: The control-plane Kustomize installer

- **Status:** Todo — **RED may begin.** ADR-0095 and ADR-0096 were Accepted 2026-09-22 as written
  and SPEC-0067 is Approved; the two *prerequisites* in Notes are not blocks on writing this task's
  tests, only on applying its output to a cluster
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
