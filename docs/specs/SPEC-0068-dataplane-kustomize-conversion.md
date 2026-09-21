# SPEC-0068: The BYO data-plane installer becomes Kustomize

- **Status:** Draft
- **Owner:** unassigned
- **Context(s):** deployment / operability (an artifact, not a product behaviour — ADR-0022 does not apply)
- **ADRs:** 0096 (Accepted 2026-09-22 — Kustomize only; decision 3 requires this conversion and
  decision 6 sets the distribution answer), 0013 (the Operator, which survives; its packaging half is
  amended), 0044 (signed releases, verify-before-apply), 0047 (registry trust), 0011 (outbound-only —
  the no-inbound property this conversion must not weaken), 0017/0060 (the agent's transport and
  identity), 0034/0035 (image pins), 0092/0095 (unrelated to this spec's plane, cited only where the
  gate is shared)
- **Amends:** **SPEC-0039 AC1** — "One `helm install` plus an enrolment token" names an engine
  ADR-0096 removed. The amendment is part of this spec's task and is a governance commit, not an
  implementation detail (see AC12).
- **Task(s):** T-0085

## Problem / context

ADR-0096 decision 3 converts `deploy/helm/gitfrok-dataplane/` to `deploy/k8s/dataplane/`. Unlike the
control plane's installer, this one exists, is installed by customers, and carries evidence: eight
assertion sections in `scripts/check-byo-chart.sh`, and conformance-matrix rows whose helm-rendered
halves went green on 2026-08-21 after being NOT RUN for most of the chart's life.

This spec exists because that evidence cannot transfer by assertion. The matrix's rule is that a
blurred row is a failed row, so rows 11 and 14 revert to "not run" with ADR-0096 as their cause and
are re-earned against `kubectl kustomize`. Nothing here may record a green row it did not run.

**Two facts about the existing trust chain, verified in the tree, that narrow this spec considerably
and correct a reading of ADR-0096 decision 6.** `scripts/check-signed-releases.sh` signs and verifies
`oci_ref@digest` — a per-component **image identity** — and a `.release` manifest carries exactly
`component`, `version`, `oci_ref`, `digest`, `signature`. **The chart has never been a signed
artifact.** Its only obligation in the trust chain is the gate's section 3: pin exactly the digest the
signed manifest records. So:

- The signing chain is **engine-agnostic** and survives this conversion untouched. Kustomize's
  `images:` transformer discharges the pinning obligation more directly than a values file did.
- ADR-0096 decision 6's "signed and distributed on ADR-0044's existing terms" is therefore **an
  addition to the trust chain, not a restatement of it**: signing a rendered manifest set requires a
  new payload type and a `.release` field the gate does not yet read. That is real work, it is a
  genuine improvement (it closes the gap where a template could alter what is applied after the
  signature was checked), and it is recorded as open question 1 rather than assumed.

## In scope

- `deploy/k8s/dataplane/` — a Kustomize base plus whatever overlay/component structure replaces the
  chart's two values-driven modes (agent-only, and `operator.enabled=true`).
- `scripts/check-byo-kustomize.sh` — sections 0–7 of `check-byo-chart.sh` ported with intent intact,
  and a `kubectl kustomize` render replacing section 8.
- Retiring `deploy/helm/gitfrok-dataplane/` and `scripts/check-byo-chart.sh`.
- The SPEC-0039 AC1 amendment, and the conformance matrix's row reversion plus re-earning.

## Out of scope

- **The control-plane installer** — SPEC-0067/T-0084, already Approved.
- **`deploy/dev`** — ADR-0096 decision 10 leaves it alone.
- **ADR-0013's Operator behaviour.** Its reconcile loop, rollout and rollback are unchanged; only
  what it applies changes. No `backend` change is in scope, and if one proves necessary that is a
  separate task (invariant 23).
- **Real-cluster execution** — T-0042's and T-0003's cluster lane. This spec's re-earning is the
  harness half: `kubectl kustomize` renders, not a cluster install.
- The signed-manifests payload of open question 1, **if** the owner decides it is a separate ADR.

## Contracts touched

None. No proto and no event changes.

## Data owned

None. The installer holds no state and authors no Secret (AC3).

## Acceptance criteria (each becomes a test)

- [ ] **AC1** `kubectl kustomize deploy/k8s/dataplane/<base|overlay>` renders both install modes —
      agent-only, and the operator-enabled mode the chart drove from `operator.enabled=true` — and
      each render is byte-identical across two runs at one revision.
- [ ] **AC2** **No inbound path, in either render**: no `Service`, `Ingress`, `Gateway`, `HTTPRoute`,
      `LoadBalancer`, `NodePort` or `hostPort` anywhere in the rendered output (ADR-0011, SPEC-0039's
      out-of-scope rule, gate section 5). This is the property that must not weaken in translation,
      and the gate is mutation-tested: adding a `Service` to the base fails it.
- [ ] **AC3** The installer authors **no `Secret`**, and no `kustomization.yaml` under
      `deploy/k8s/dataplane/` contains a `secretGenerator` (ADR-0096 decision 5, gate section 2).
      Mutation-tested.
- [ ] **AC4** The enrolment token reaches the container **only** by `secretKeyRef`, never as a
      literal, never in a rendered file, and never in a written-back artifact — and a
      `--set`-equivalent overlay patch carrying a token sentinel never reaches rendered output (gate
      sections 1, 3 and section 8's sentinel assertion). Mutation-tested with the sentinel.
- [ ] **AC5** The `DataPlane` CR is reference-only and its status carries no credential (gate
      section 4).
- [ ] **AC6** Every first-party image is pinned by **digest** through `images:`, and the operator's
      digest is exactly the one its signed `.release` manifest records — gate section 3's assertion,
      carried over (SPEC-0045 AC1, ADR-0034/0035).
- [ ] **AC7** The reconcile contract stays named rather than implied, including the
      `operator.image.tag`-is-retired tripwire the chart carried (gate section 7).
- [ ] **AC8** **The CRD's upgrade semantics are stated and tested.** Helm's `crds/` directory is
      installed once and never upgraded or deleted by Helm; Kustomize has no such special case, so
      the CRD becomes an ordinary resource that `kubectl apply` will update in place. The conversion
      must not let a CRD update destroy or orphan a stored `DataPlane` (SPEC-0039 AC8 — upgrades
      never destroy tenant data). Either the CRD is excluded from the applied set with its lifecycle
      documented, or its in-place update is proven non-destructive across the version window.
- [ ] **AC9** `scripts/check-byo-kustomize.sh` reproduces every assertion of sections 0–7 and is
      **failable**: a negative fixture per assertion exits non-zero, and the shipped tree exits zero.
      A blurred or skipped assertion is a failed criterion.
- [ ] **AC10** `deploy/helm/gitfrok-dataplane/` and `scripts/check-byo-chart.sh` no longer exist, and
      no `helm` invocation remains in any script under `scripts/` (ADR-0096 decision 1).
- [ ] **AC11** **Conformance rows 11 and 14 read "not run" with ADR-0096 recorded as the cause, then
      carry their re-earned harness evidence against `kubectl kustomize`** — never the 2026-08-21
      helm evidence, which names a tool the tree no longer has. The two must be distinguishable on
      the row, per the matrix's own harness/real-cluster separation.
- [ ] **AC12** **SPEC-0039 AC1 is amended** so it no longer names `helm install`, and SPEC-0039's
      status and the specs index reflect the amendment. A governance commit, separate from the
      super-repo commits (invariant 23).
- [ ] **AC13** The install's required inputs still refuse to be missing. Helm's `required` failed a
      render on an absent value; Kustomize renders an empty env without complaint, so the refusal
      moves into the gate and into `cmd/dataplane-app`'s existing `require()` path — which already
      refuses at startup (`agent.go`). The gate asserts the render carries no empty required env, and
      the existing startup refusal tests stay green as the second line.
- [ ] **AC14** **The customer is told what to do next.** `templates/NOTES.txt` printed post-install
      guidance and Kustomize has no equivalent, so that content moves somewhere a customer reads —
      the runbook or the install docs — and a gate asserts it is not merely deleted.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | AC2 is ADR-0011's no-inbound property made executable against the new renderer, mutation-tested; AC5 keeps credentials off the CR |
| G4 change governance | AC9 keeps the gate failable rather than merely present; AC11 refuses inherited green; AC12 makes the spec amendment a reviewed governance act rather than a silent edit |
| G6 compliance | AC3, AC4 and AC5 keep every credential out of the tree, the render and the written-back artifacts |
| G7 residency | Untouched — residency is declared through `residency/v1` (SPEC-0043), not by the installer |

## Non-functional

- Deterministic renders (AC1), so a version-to-version diff is reviewable.
- No templating language: plain manifests plus patches. The chart's `_helpers.tpl` has no successor by
  design.
- `kubectl`'s built-in Kustomize — no new binary, no new version floor.
- The conversion is a **no-behaviour-change** change to what runs in a customer's cluster: the same
  workloads, the same digests, the same absence of inbound paths. Any behavioural difference is a
  defect of this spec, not a feature of it — AC8 is the one place a difference is unavoidable and it
  is therefore stated rather than discovered.

## Open questions / assumptions

1. **Does ADR-0096 decision 6 require a new signed payload, and is that this task's?** The tree signs
   `oci_ref@digest` per component; the chart was never signed. Signing a rendered manifest set means a
   new payload type and a `.release` field `check-signed-releases.sh` does not read. Three readings:
   (a) decision 6 describes exactly that and T-0085 builds it; (b) decision 6 is satisfied by the
   existing image-digest chain plus AC6's pinning, and "the release artifact becomes the rendered
   manifests" is aspirational; (c) it is a separate decision and wants its own ADR. **This is the
   largest open question in the spec and it changes T-0085's size materially.** Until it is settled,
   AC6 carries the obligation that is certainly required and the rest waits.
2. **What replaces `values.yaml` as the customer's documented input surface?** A values file was also
   a contract with the customer about what they may set. Overlay patches are not self-documenting, and
   ADR-0094's open row already notes the data-plane door has no published contract. These two gaps are
   adjacent and may want answering together.
3. **How are the two install modes structured** — two overlays, or a Kustomize `component` for the
   operator? Affects AC1's shape and the overlay-variance rule ADR-0096's follow-up asks for.
4. **AC8's CRD answer is genuinely open.** Excluding the CRD from the applied set preserves Helm's
   semantics but leaves its installation unowned; including it makes upgrades simpler and needs the
   non-destructive proof. This is a real decision about a customer's stored data and should not be
   made by whoever writes the first `kustomization.yaml`.
5. **Whether T-0042's matrix scope changes.** AC11 reverts two rows this spec re-earns in the harness
   lane; T-0042 owns the real-cluster halves and inherits whatever AC11 leaves. Its task file needs the
   scope note.
6. This spec is `Draft`: open questions 1 and 4 are decisions, not details, and approving it before
   they are answered would hand T-0085 an instruction to improvise on a customer-facing artifact.
