# ADR-0103: The BYO installer's CRD is applied separately, and the signed bundle needs a payload the tree does not have

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (written after SPEC-0068 refused to leave Draft with two decisions open)
- **Related:** ADR-0096 (Kustomize only — decision 3 orders this conversion, decision 6 is half of what
  this ADR settles), ADR-0013 (the Operator, whose reconcile loop this ADR declines to change),
  ADR-0044 (signed releases, verify-before-apply), ADR-0065 (digest pins, release-key rotation),
  ADR-0034/0035 (image pins), ADR-0011 (outbound-only), SPEC-0039 (the BYO install contract — AC8 is
  the property decision 1 protects), SPEC-0068 (Draft; open questions 1 and 4 are what this ADR
  answers), T-0085 (sized by this ADR)
- **Governs:** G1 isolation, G4 change governance, G6 compliance, operability

## Context

SPEC-0068 converts `deploy/helm/gitfrok-dataplane/` to `deploy/k8s/dataplane/` and closes itself with
a refusal: *"open questions 1 and 4 are decisions, not details, and approving it before they are
answered would hand T-0085 an instruction to improvise on a customer-facing artifact."* Those two
questions are the CRD's upgrade semantics and whether ADR-0096 decision 6 requires a new signed
payload. Both were left open honestly. Both are answered here, and the second turned out to be a
contradiction rather than a question.

**What the tree actually does today, measured rather than assumed.**

The CRD is `dataplanes.byo.gitfrok.dev`, `scope: Namespaced`, with exactly one version — `v1alpha1`,
`served: true`, `storage: true`. It ships in the chart's `crds/` directory, which Helm installs once
and thereafter never upgrades and never deletes. That special case is the whole of the CRD's
lifecycle policy today, and it is Helm's, not ours: Kustomize has no `crds/` concept, so a
translation that does nothing makes the CRD an ordinary resource in the applied set.

The Operator's release path is narrower than ADR-0096 decision 6 reads as though it were.
`backend/cmd/operator-app/release.go` parses a `.release` of exactly `component`, `version`,
`oci_ref`, `digest`, `signature`; `CanonicalIdentity()` returns `oci_ref + "@" + digest` and its own
comment states what that value is for: *"the exact image reference the applier converges the workload
onto: a digest pin, never a mutable tag."* The Operator converges **one image digest**. It does not
fetch a bundle, does not verify a signature over a set of manifests, and has no applier that applies
N objects.

ADR-0096 decision 6 says the release artifact *is* the rendered output of `deploy/k8s/dataplane/`,
signed on ADR-0044's terms, and that *"ADR-0013's Operator is unchanged and is now the install
ergonomics: it reconciles the verified bundle."* Against the code above, "unchanged" is not
available: reconciling a verified bundle is a new payload type, a new verification target, and a new
applier. SPEC-0068 meanwhile states *"No `backend` change is in scope, and if one proves necessary
that is a separate task (invariant 23)."*

**So ADR-0096 decision 6 and SPEC-0068's scope contradict each other, and T-0085 is where the
contradiction would have been discovered by whoever wrote the first `kustomization.yaml`.** That is
the thing this ADR exists to prevent.

## Decision

**1. The `DataPlane` CRD leaves the installer's applied set and gets its own lifecycle.** It lives at
`deploy/k8s/dataplane/crd/` with its own `kustomization.yaml`, is applied once before the workload
overlay, and is never a member of what the workload apply — or the Operator's reconcile — manages.
This is the shape `deploy/k8s/platform/operators/cloudnative-pg/` already uses for the CNPG operator
and its CRDs, so the tree gains no new concept.

**2. The property being protected is that uninstalling a workload must never destroy a tenant's
stored `DataPlane` objects.** Deleting a CRD garbage-collects every custom resource of that kind,
cluster-wide. A CRD inside the applied set therefore turns `kubectl delete -k` — and any pruning
apply — into silent tenant-data destruction, which SPEC-0039 AC8 forbids. Helm's `crds/` exemption
was load-bearing, and translating it to "an ordinary resource" would have been a behaviour change
disguised as a format change. SPEC-0068's own non-functional rule says any behavioural difference is
a defect of the spec; this is the one place the difference was unavoidable, so it is decided here
rather than discovered.

**3. In-place CRD *update* stays permitted, because with one stored version it is not the hazard.**
`v1alpha1` is both served and storage, so `kubectl apply` on the CRD updates the schema while stored
objects stay where they are. The gate asserts the CRD is absent from the workload render, not that it
is never applied.

**4. The non-destructive proof is deferred to the version that needs it, and named now.** The moment a
second version is served — `v1beta1`, or `v1` — in-place update acquires the risk decision 3 says it
lacks today: a storage-version change requires a conversion strategy and a storage migration of every
existing object, and getting it wrong orphans stored `DataPlane`s rather than destroying them
visibly. That work belongs to whichever task adds the second version, and it must not be discovered
then either.

**5. ADR-0096 decision 6 is not re-litigated: the release artifact becomes the rendered manifest set.**
SPEC-0068 offered three readings of decision 6; decision 6's own text picks one — *"only the payload's
format changes"* — and the gain it claims is real. Rendering at release time means what is signed is
what is applied, with no template evaluated on a customer's cluster after verification. This ADR
affirms that direction and changes none of it.

**6. But T-0085 does not build it, because it cannot without a `backend` change.** The bundle payload
needs a `.release` that can name a manifest set rather than an image, a verifier that hashes that
payload, and an Operator applier that applies a set. `scripts/check-signed-releases.sh`,
`modules/rollout`'s verifier and `cmd/operator-app` all read the `oci_ref@digest` shape. That is a
separate task in `backend` under invariant 23, and it is not a prerequisite of the conversion.

**7. Until that task lands, the data-plane installer's trust obligation is the existing per-image
digest chain, unchanged.** SPEC-0068's AC6 already carries it: every first-party image pinned by
digest through Kustomize's `images:` transformer, and the operator's digest exactly the one its signed
`.release` records. This chain is engine-agnostic — it signs image identities, never chart or manifest
text — so it survives the conversion untouched, and the chart was never a signed artifact to begin
with. **The conversion does not weaken the trust chain; it also does not yet strengthen it the way
decision 6 intends.** Both halves are stated so no gate records a green it did not earn.

**8. `deploy/k8s/dataplane/` is therefore not a complete answer to ADR-0096 decision 6 when T-0085
finishes, and T-0085's exit record must say so.** A reader who finds the conversion done and decision
6 open is looking at the intended state, not an abandoned one.

## Consequences

- **T-0085 shrinks and stops being ambiguous.** It converts, ports the gate, retires the chart, and
  carries the CRD as a separately-applied resource. It does not touch `backend` and does not invent a
  payload format.
- **The customer's install gains a step**: apply the CRD directory once, then the overlay. Helm hid
  this behind `crds/`. It is now visible, which is the correct trade for the deletion hazard it
  removes, and SPEC-0068 AC14 already requires the post-install guidance to land somewhere a customer
  reads.
- **A new gate assertion** for `scripts/check-byo-kustomize.sh`: the workload render contains no
  `CustomResourceDefinition`. Mutation-tested like the rest, per SPEC-0068 AC9.
- **ADR-0096 decision 6 stays open after T-0085**, tracked as an open question below rather than
  silently satisfied. This is the cost of decision 6 being written before the Operator's release path
  was measured.
- **Two installers now apply CRDs out-of-band** — CNPG on the control plane, `DataPlane` on a
  customer's cluster. That is a consistent shape, not two exceptions, but nothing yet asserts the
  consistency.
- **SPEC-0068 can leave Draft.** Its open questions 2, 3 and 5 remain, and are details the spec's
  owner may settle: the customer input surface that replaces `values.yaml`, whether the two install
  modes are overlays or a Kustomize component, and T-0042's matrix scope.

## Alternatives considered

**Keep the CRD in the applied set and rely on a prune guard.** Kustomize and `kubectl apply` offer no
durable "never delete this" annotation that survives a customer running `kubectl delete -k` by hand.
The protection would be documentation, and the failure mode is silent destruction of tenant data.
Rejected on blast radius, not on elegance.

**Exclude the CRD and leave its installation unowned**, as SPEC-0068's open question 4 feared. This is
the alternative decision 1 nearly is — the difference is that the CRD gets an owned directory, an
apply order and a gate assertion, rather than a sentence in a README. Unowned was the real risk; a
separate owner is not.

**Build the bundle payload inside T-0085.** It would satisfy ADR-0096 decision 6 in one task, and it
would put a `backend` change inside a task scoped to `deploy/`, crossing invariant 23's submodule
boundary and making the conversion hostage to a new trust-chain format. Rejected: the conversion is
valuable on its own, and the payload deserves its own review rather than arriving as a subsection of
an installer port.

**Declare decision 6 already satisfied by AC6's digest pinning** — SPEC-0068's reading (b). This is
tempting because it would close the question with no work, and it is false: decision 6's stated gain
is that no template is evaluated after verification, which per-image digest pinning does not provide.
Rejected as recording a green that was not earned.
