# SPEC-0067: The control-plane Kustomize installer

- **Status:** Approved (2026-09-22)
- **Owner:** unassigned
- **Context(s):** deployment / operability (no bounded product context — this describes an artifact,
  not a behaviour of the product; ADR-0022 does not apply)
- **ADRs:** 0096 (the installer is Kustomize — **Accepted 2026-09-22**), 0093 (the boundary
  decisions carried over), 0095 (the public surface this overlay renders — **Accepted
  2026-09-22**), 0092 (the environment it installs into), 0024 (the dev environment it is
  not), 0034/0035 (image pins), 0066 (sealed-until-unsealed), 0094 (the repository surface is not here)
- **Task(s):** T-0084

## Problem / context

ADR-0092 provisions a control-plane cluster and nothing can deploy into it. ADR-0093 decided an
installer and it was never built: `deploy/helm/` holds only `gitfrok-dataplane`, and no spec or task
ever referenced ADR-0093. ADR-0096 replaces its engine with Kustomize before anything exists to
migrate. This spec says what "built" means for that installer in testable terms.

Both ADRs this spec depends on were **Accepted on 2026-09-22 as written**, so the condition that held
this spec at `Draft` is discharged and **RED may begin**. Neither acceptance changed a decision this
spec restates, so no acceptance criterion needed amending — recorded because the reverse would have
obliged an edit here before approval.

## In scope

- A Kustomize `base/` rendering the three first-party control-plane workloads — `controlplane-app`,
  `bff`, `webfrontend` (ADR-0093's partition as amended by ADR-0094).
- An `overlays/prod-cp/` carrying ADR-0092's control-plane environment, including ADR-0095's Gateway
  listener, the L4 agent-door Service, and references to the reserved addresses.
- Digest-pinned images through Kustomize's `images:` transformer.
- `scripts/check-controlplane-kustomize.sh` — the gate ADR-0096 decision 5 requires.

## Out of scope

- **The data-plane conversion** (ADR-0096 decision 3) — SPEC-0068/T-0085, a separate unit of work
  that amends SPEC-0039, rewrites `check-byo-chart.sh` and re-earns conformance rows 11 and 14.
- **`deploy/dev`** — untouched by ADR-0096 decision 10.
- **The third-party stateful set** — Postgres, Valkey, Redpanda, OpenBao, Zitadel are *required
  inputs*, and their production install is ADR-0093 decision 2's still-open row. **This spec being
  met does not produce a serving control plane**, and nothing here should be read as claiming it does.
- **Cluster provisioning** — OpenTofu's, per ADR-0092 decision 4.
- **DNS records and the reserved addresses themselves** — ADR-0095's, operator-side and OpenTofu-side
  respectively. This overlay *references* an address; it does not create one.
- **Applying anything to a real cluster** — T-0003's cluster lane, as every infrastructure-bound
  demonstration since Phase 1.
- GitOps; signing (the control-plane installer is vendor-internal per ADR-0093 decision 7).

## Contracts touched

None. No gRPC service and no event changes — this is a deployment artifact.

## Data owned

None. The installer holds no state; every credential is a name reference to a Secret it does not
create (AC4).

## Acceptance criteria (each becomes a test)

- [ ] **AC1** `kubectl kustomize deploy/k8s/controlplane/overlays/prod-cp` renders without error and
      emits exactly the three first-party workloads — `controlplane-app`, `bff`, `webfrontend` — and
      no fourth Deployment or StatefulSet.
- [ ] **AC2** The render contains **no** Postgres, Valkey, Redpanda, OpenBao or Zitadel workload.
      Each appears only as configuration referring to an endpoint (ADR-0093 decision 2, carried by
      ADR-0096 decision 4).
- [ ] **AC3** No `kustomization.yaml` under `deploy/k8s/` contains a `secretGenerator`, and the
      rendered output contains **no** `Secret` object authored by this tree (ADR-0096 decision 5).
      The gate is mutation-tested: adding a `secretGenerator` makes it exit non-zero.
- [ ] **AC4** Every credential — the database URL's password, the OIDC client secret, the session key
      — reaches a container through `secretKeyRef` or `envFrom.secretRef` naming a pre-existing
      Secret. No credential appears as a literal env value or in any overlay file.
- [ ] **AC5** Every first-party image in the render is pinned by **digest** (`@sha256:`), not by tag,
      through the `images:` transformer (ADR-0034/0035, ADR-0096 decision 9). **Unmet 2026-09-22 for
      want of inputs, not effort:** no published digest exists for `controlplane-app`, `bff` or
      `webfrontend` — `versions.env` pins them by tag and records that they are never published to an
      external registry, and `deploy/releases/` covers only `dataplane-app` and `operator-app`. The
      gate reports this as NOT RUN with the cause named rather than passing. Closes when the three
      images are first published to `prod-cp`'s Artifact Registry.
- [ ] **AC6** The agent door renders as a `Service` of `type: LoadBalancer` with TCP passthrough, and
      carries **no** L7 route, no `HTTPRoute` reference and no L7 annotation (ADR-0095 decisions 3
      and 5). The gate is mutation-tested: attaching an `HTTPRoute` to it fails.
- [ ] **AC7** The browser and issuer hosts render behind a Gateway API listener, including a listener
      on port 80 for ACME HTTP-01 (ADR-0095 decisions 2 and 7). Hostnames come from the overlay, not
      the base.
- [ ] **AC8** Both public addresses are **referenced** as reserved static addresses, and the render
      fails a gate assertion if either would take an ephemeral address (ADR-0095 decision 6). The
      addresses are not created here.
- [ ] **AC9** The workloads model sealed-until-unsealed: each has a readiness probe that reports
      unready while OpenBao custody is unavailable, and no init container or job blocks indefinitely
      on it (ADR-0093 decision 4, ADR-0066 decision 4). A cold render plus apply yields workloads
      that start and report unready rather than crash-looping.
- [ ] **AC10** `scripts/check-controlplane-kustomize.sh` exits non-zero for each of AC3, AC5, AC6 and
      AC8's negative cases, and zero on the tree as shipped — the gate is failable, proven by fixtures
      rather than asserted.
- [ ] **AC11** `base/` renders on its own without the overlay, so the overlay is additive and the
      base is reviewable; and the overlay changes only hostnames, addresses, replica counts and image
      digests — nothing that alters which workloads exist (the overlay-variance rule ADR-0096's
      follow-up asks for, stated here for the one overlay that exists).
- [ ] **AC12** No `helm` invocation, chart, or `values.yaml` exists anywhere under
      `deploy/k8s/controlplane/`, and `deploy/helm/gitfrok-controlplane/` does not exist (ADR-0096
      decision 1).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | AC2 keeps the installer's boundary at the first-party workload, so the control plane's stateful dependencies stay separately owned and separately upgradable; AC6 keeps the agent door's L4 shape, which is what stops an intermediary asserting a caller's identity (SPEC-0002 limit (d)) |
| G4 change governance | AC3, AC5, AC6, AC8 and AC10 are a build-blocking gate rather than a convention, and AC10 proves the gate can fail; ADR-0096 decision 8's rollback-by-revision is what makes an applied change reversible |
| G6 compliance | AC4 keeps every credential out of the tree and out of rendered output, so no artifact under review carries a secret |
| G7 residency | Untouched: the overlay installs into the region ADR-0092 decision 8 already fixes as an input; nothing here decides placement |

## Non-functional

- The render is deterministic: two runs at one revision produce byte-identical output, so a diff
  between revisions is reviewable (the property ADR-0096's "reviewable as plain manifests" claims).
- No templating language. Plain manifests plus patches only.
- `kubectl`'s built-in Kustomize — no separate binary, so no new version floor beyond `kubectl`'s.

## Open questions / assumptions

1. ~~ADR-0095 and ADR-0096 are both Proposed.~~ **Closed 2026-09-22:** both Accepted as written, with
   no change to any decision AC1–AC8 restate. The spec is Approved and RED may begin.
2. ~~Whether the readiness shape of AC9 is a probe or a dedicated gate.~~ **Answered 2026-09-22, and
   the answer stops AC9.** `controlplane-app` serves one `/healthz` endpoint used for both liveness
   and readiness (`deploy/dev/controlplane.yaml`); nothing distinguishes "OpenBao sealed" from
   "OpenBao unreachable". T-0084 therefore stopped rather than adding a probe path the binary does
   not honour, and **AC9 is unmet pending a backend task for a custody-aware readiness endpoint**.
   Until it exists the Deployment reports Ready while custody is sealed and the agent door refuses —
   which is ADR-0093 decision 4's behaviour observed, not modelled.
3. **AC8's mechanism depends on an unfiled follow-up.** ADR-0095 decision 6 requires reserved
   addresses and does not place them; until that unit exists, AC8 can assert only that the overlay
   references an address by name and never requests an ephemeral one.
4. **AC11's overlay-variance rule is stated for one overlay.** ADR-0092 already shapes `live/` for
   staging; the rule may need widening when the second overlay arrives, and widening it is cheaper
   than retrofitting it.
5. **Meeting this spec does not produce a working control plane** — ADR-0093 decision 2's third-party
   stateful set is still unowned by any artifact, and it blocks a first deployment independently of
   this work. Recorded here so the task's Done cannot be read as "deployed".
