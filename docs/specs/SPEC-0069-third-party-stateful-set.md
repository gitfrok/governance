# SPEC-0069: The third-party stateful set, installed

- **Status:** Approved (2026-09-22)
- **Owner:** unassigned
- **Context(s):** deployment / operability (an artifact, not a product behaviour — ADR-0022 does not apply)
- **ADRs:** 0099 (**Accepted 2026-09-22**), 0093 decision 2
  (these are inputs), 0096 (Kustomize only), 0066 (OpenBao's gated shape), 0092 (in-cluster, and the
  backup bucket this narrows), 0033/0050 (storage tiers), 0052 (the session store's startup
  contract), 0095/0097 (nothing here is publicly reachable), 0034 (image pins)
- **Task(s):** T-0086

## Problem / context

ADR-0093 decision 2 made six third-party components required inputs to the control-plane installer
and left their production install unowned; ADR-0099 decides how they install. This spec says what
"installed" means in testable terms, ADR-0099 was Accepted as written on
2026-09-22, so RED may begin and no criterion needed amending.

The trap this spec exists to avoid is promoting `deploy/dev`. Five of the six are single-replica
`Deployment`s with a ReadWriteOnce PVC there, which cannot roll: the incoming pod cannot attach the
volume the outgoing one holds. That shape deploys and then fails on its first upgrade, in a way that
reads as a storage fault rather than a design error.

## In scope

- `deploy/k8s/platform/base/<component>/` and overlays `prod-cp`, `prod-dp`.
- The CloudNativePG operator install and two `Cluster` resources (ADR-0099 decision 2).
- A `backups` OpenTofu unit for the Postgres backup bucket (decision 5).
- `scripts/check-platform-kustomize.sh` and its negative fixtures.

## Out of scope

- **`deploy/dev`** — ADR-0024 owns it; ADR-0096 decision 10 declined convergence.
- **Creating any credential.** Every Secret is a named input (decision 7) and an operator seam.
- **Unsealing OpenBao.** ADR-0066 decision 4 keeps a human quorum in the path, forever.
- **Backup retention and the PITR window** — ADR-0099's follow-up.
- **SeaweedFS replication** — ADR-0099 decision 4 states it is undecided.
- **The upgrade ORDER** across Postgres, Zitadel and the control-plane app — a follow-up, and the
  thing most likely to be discovered the hard way.
- Applying anything to a cluster: T-0003's lane, as always.

## Contracts touched

None.

## Data owned

None by the installer. It creates the *homes* for other software's data and owns no schema.

## Acceptance criteria (each becomes a test)

- [ ] **AC1** `kubectl kustomize deploy/k8s/platform/overlays/prod-cp` renders Postgres (a CNPG
      `Cluster`), Valkey, Redpanda, OpenBao and Zitadel; `overlays/prod-dp` renders Postgres,
      Redpanda and SeaweedFS and **no OpenBao and no Zitadel** — ADR-0066's control-plane-only rule,
      which `check-custody-service.sh` already asserts for the dev manifest.
- [ ] **AC2** Every stateful component renders as a `StatefulSet` with `volumeClaimTemplates`. A
      `Deployment` carrying a PVC fails the gate (ADR-0099 decision 3). Zitadel is exempt and must be
      a `Deployment`, because it is stateless given Postgres.
- [ ] **AC3** Replica counts match ADR-0099 decision 4 exactly — Postgres 3, OpenBao 3, Redpanda 3,
      Zitadel 2, Valkey 1, SeaweedFS 1 — and the gate fails on any change, so a scale-down is a
      failed build rather than a silent regression.
- [ ] **AC4** No authored `Secret`, no `secretGenerator`, and every credential arrives by
      `secretKeyRef`/`envFrom.secretRef` naming a pre-existing Secret (ADR-0096 decision 5).
      Mutation-tested.
- [ ] **AC5** No `Service` of type `LoadBalancer` or `NodePort`, no `Gateway`, no `HTTPRoute`, no
      `hostPort` in either overlay (ADR-0099 decision 8). Mutation-tested.
- [ ] **AC6** Every image is digest-pinned and every pin resolves to `deploy/dev/versions.env`, so one
      record governs both environments (ADR-0034, ADR-0098). Where no digest is published, the gate
      reports NOT RUN with that cause named rather than passing.
- [ ] **AC7** OpenBao's production manifest carries everything `check-custody-service.sh` asserts of
      the dev one — three replicas, the control-plane placement label, Shamir-only unseal with **no**
      seal stanza, no static credential, and the ServiceAccount plus token-review delegation — and
      the gate is **taught the production path** so the assertion covers what actually runs.
- [ ] **AC8** OpenBao terminates **TLS**, and neither the busybox loopback proxy nor
      `GITFROK_CUSTODY_ALLOW_LOOPBACK_HTTP` appears anywhere under `deploy/k8s/` (ADR-0099 decision
      6). This is what makes `deploy/k8s/controlplane/base`'s `https://openbao:8200` true.
- [ ] **AC9** The CNPG `Cluster` declares a backup target in the bucket the `backups` unit provisions,
      and the gate fails if `backup` is absent — "we will add backups later" is how unrecoverable
      loss is scheduled (decision 5).
- [ ] **AC10** Storage classes are explicit and block-backed for the tiers ADR-0033 requires; no
      component relies on the cluster's default class.
- [ ] **AC11** `scripts/check-platform-kustomize.sh` exits non-zero for a negative fixture per
      AC2–AC5 and AC9, and zero on the tree as shipped — failability proven by fixtures, not asserted.
- [ ] **AC12** Renders are deterministic: two runs at one revision are byte-identical.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | AC1 keeps OpenBao control-plane-side and Zitadel out of the data plane; AC5 keeps the whole set inside the VPC, so ADR-0097's private endpoints are not the only thing between a mistake and the internet |
| G4 change governance | AC3 and AC11 make replica counts and the gate's failability build-blocking; AC7 closes a gate that currently proves properties about a Minikube file while production runs a different one |
| G6 compliance | AC4 keeps every credential out of the tree and the render; AC9 makes recoverability a criterion rather than an intention |
| G7 residency | Untouched: both overlays install into the region ADR-0092 decision 8 fixes as an input |

## Non-functional

- A rolling update of any component completes without a volume-attachment stall — the defect AC2
  exists to prevent, and the reason the dev shape cannot be promoted.
- No templating language: plain manifests plus patches (ADR-0096).
- The CNPG operator manifest is vendored at a pinned version, not fetched at apply time, so an
  install is reproducible and reviewable.

## Open questions / assumptions

1. ~~ADR-0099 is Proposed.~~ **Closed 2026-09-22:** Accepted as written, with no change to any
   decision these criteria restate.
2. **The CNPG version and its vendoring path are unchosen.** A pinned operator manifest is a
   substantial vendored artifact and its upgrade cadence is a real obligation — the cost ADR-0099
   accepts for one component and refuses for four.
3. **`check-custody-service.sh` currently hardcodes the dev path.** AC7 requires teaching it a second
   one, and whether it takes a path argument or learns a list is an implementation choice with a
   gate-scope consequence: a list that silently matches nothing would pass.
4. **Meeting this spec still does not produce a login.** OpenBao is sealed until a human quorum acts
   (ADR-0066 decision 4), seven credentials are manual seams, and the first-party images must be
   published first (ADR-0098). Recorded so the task's Done cannot be read as "serving".
