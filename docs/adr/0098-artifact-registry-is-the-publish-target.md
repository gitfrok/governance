# ADR-0098: Artifact Registry is the publish target for first-party images, and it is made publicly pullable on purpose

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (directed by the deciding owner)
- **Amends:** **ADR-0047's registry choice.** That ADR says "we will publish first-party **release**
  images in `ghcr.io/gitfrok` as publicly pullable OCI artifacts"; this replaces `ghcr.io/gitfrok`
  with Artifact Registry. **Everything else in ADR-0047 survives unchanged** — the digest
  requirement, Cosign verification against the versioned per-environment trust bundle, public
  visibility not authorizing execution, publish authority restricted to a protected workflow from
  reviewed `main` or a `v*` tag, and mirrors changing transport rather than the digest. ADR-0047 is
  Accepted and is not edited (ADR-0001).
- **Related:** ADR-0010 (cloud portability — **this spends some of it**, see the costs), ADR-0013
  (air-gapped mirrors), ADR-0034 (image pins that resolve to one thing forever), ADR-0035
  (first-party images: scratch, digest, signed), ADR-0044 (signed releases, verify before apply),
  ADR-0053 (direct-to-main CI is the gate), ADR-0092 (the first-party cloud; this discharges its
  Artifact Registry follow-up), ADR-0096 decision 9 (digest pins in the `images:` transformer),
  SPEC-0067 AC5 (unmet today for want of a published digest)
- **Governs:** G4 change governance, G6 compliance, operability

## Context

**Nothing is published anywhere, and three different registries appear in the tree.** Verified
2026-09-22:

| Where it is written | What it says | What is actually there |
|---|---|---|
| ADR-0047 (Accepted) | `ghcr.io/gitfrok`, publicly pullable | nothing |
| `deploy/dev/versions.env` | `docker.io/gitfrok/{controlplane-app,bff,webfrontend,dataplane-app}` | **404 on all four** |
| `deploy/gcp` Artifact Registry | repository `gitfrok` exists, immutable tags | **empty** |

So `versions.env` has carried a registry string that matches no decision and holds no image, and
nothing noticed because `check-dev-images.sh` exempts first-party images from registry resolution —
correctly, since `dev-up.sh` builds them into the Minikube node with `minikube image build` and never
pushes. The exemption was right for a laptop and it hid the gap the moment a real cluster existed.

**The consequence is not subtle.** Both GKE clusters run, DNS resolves, addresses are reserved, and
the Kustomize installer renders — and every pod it renders would land in `ImagePullBackOff`, because
the images it names do not exist. This is the first blocker in the chain, not a later one: the
third-party stateful set and the BFF's reader premise are both downstream of having something to run
at all.

The deciding owner has directed **Artifact Registry**. That is a choice between two registries that
ADR-0047 already settled once, so this ADR amends it rather than closing a follow-up — ADR-0092's
register row characterized ADR-0047 as leaving the target open, and reading ADR-0047's decision text
shows it did not.

One property of ADR-0047 is load-bearing and easy to lose in the move. **Public pullability is not a
convenience; it is what makes BYO work.** A customer's data plane, on their GKE, EKS or AKS, pulls
first-party images into a cluster we do not administer, and ADR-0047 states plainly that "development
and operator manifests must not contain GHCR pull credentials for first-party release images." GHCR
packages are public by a visibility flag. **Artifact Registry repositories are private by default**,
and `deploy/gcp/live/prod-cp/artifact-registry/terragrunt.hcl` leaves `reader_members` empty with a
comment saying opening it to `allUsers` "is a decision ADR-0047 permits but this unit should not make
silently." This ADR is where that is made, not silently.

## Decision

**1. `asia-southeast1-docker.pkg.dev/gitfrok-prod-cp/gitfrok` is the publish target for first-party
images**, replacing `ghcr.io/gitfrok`. Digests resolved from it are the source of record for every
pin: `deploy/dev/versions.env`, ADR-0096 decision 9's `images:` transformer, and the `.release`
manifests alike.

**2. The repository is made publicly readable, deliberately and visibly.** `reader_members` gains
`allUsers`, which grants `roles/artifactregistry.reader` and nothing else. This preserves ADR-0047's
property rather than quietly dropping it: a BYO customer pulls without a vendor credential, and no
operator manifest needs a pull secret. ADR-0047's sentence stands unamended — **public visibility
does not authorize execution, bypass the PDP, or permit a release request to provide its own key or
signature.**

**3. Signing and verification are untouched.** Cosign signatures against the versioned
`deploy/dev/trust/image-publish/` bundle, `.release` manifests signing `oci_ref@digest`, and
`scripts/check-signed-releases.sh` all keep working: only the `oci_ref` string changes. This is the
whole reason the move is cheap — ADR-0044's chain is registry-agnostic because it signs an image
identity, not a registry.

**4. `docker.io/gitfrok/*` is retired from the tree.** It named a registry no ADR chose and holds
nothing. `versions.env` moves to the Artifact Registry path, and first-party images stay exempt from
`check-dev-images.sh`'s registry resolution **only for the dev environment**, where `dev-up.sh` still
builds locally.

**5. Publish authority keeps ADR-0047's shape and changes its credential.** Only a protected
`image-publish` workflow run from reviewed `main` or a `v*` tag may publish, and pull-request jobs
stay build-only with no signing material. It authenticates to GCP by **Workload Identity Federation**
— keyless, no service-account key anywhere — consistent with ADR-0092's refusal to let a secret be an
input and ADR-0010 §3's keyless seam. The federation setup itself is a follow-up; what this decision
fixes is that **no service-account key is created for it, ever**.

**6. Immutable tags stay on, and the digest is still what anything pins.** The repository already sets
`immutable_tags = true` (ADR-0034). A tag is a human convenience; every manifest, release and overlay
resolves `@sha256:`.

**7. Air-gapped installs are unaffected.** ADR-0013's mirror changes transport, not the digest or the
verification key — ADR-0047's sentence, carried verbatim because it is exactly as true of Artifact
Registry as of GHCR.

## Consequences

**Positive:**
- The first blocker in the deployment chain closes. Something can be published, therefore something
  can run.
- **SPEC-0067 AC5 becomes satisfiable** — it is unmet today only because no published digest exists,
  and `check-controlplane-kustomize.sh` reports it as NOT RUN with that exact cause.
- The registry is already provisioned, with immutable tags, in the project that owns the control
  plane — one of the four cloud APIs ADR-0092 decision 5 accepted, so no new dependency class.
- `prod-dp` reads it through the documented cross-project seam, and a public repository makes that
  seam simpler rather than harder.
- Decision 4 removes a string that has been lying in `versions.env` since T-0021.
- Decision 5 keeps the publish path keyless, which GHCR's token model did not.

**Negative / costs:**
- **This spends portability that ADR-0010 was protecting.** GHCR is cloud-neutral; Artifact Registry
  is GCP. Every BYO install on EKS or AKS now pulls first-party images from Google, so a GCP outage
  or a change to Artifact Registry's public-access policy affects customers who chose another cloud.
  ADR-0092 decision 5 kept the cloud dependency to four APIs *for our own infrastructure*; this
  extends one of them into **every customer's install path**, which is a different and larger claim.
  It is the main cost here and it is chosen, not overlooked.
- **We now pay egress for customer pulls.** A public GHCR package is GitHub's bandwidth; a public
  Artifact Registry repository is ours, billed per GB to `gitfrok-prod-cp`. Unmetered and unbudgeted
  as of this ADR.
- **`allUsers` on a registry is a standing decision that will look alarming in an audit** unless the
  reason travels with it. Decision 2 is why it exists; the terragrunt input should carry the same
  sentence.
- **ADR-0047's publish chain has to be rebuilt**, not merely re-pointed: a protected workflow that
  held a GHCR token now needs Workload Identity Federation, and until that exists publishing is a
  manual act by whoever holds the credentials — which is exactly the state ADR-0047's "only protected
  workflow runs may publish" was written to prevent.
- A single regional repository is a single point of failure for every install. Artifact Registry has
  no multi-region mode for Docker repositories in this shape, so the answer, if one is wanted, is a
  second repository and a mirror.

**Follow-ups:**
- **Workload Identity Federation for the publish workflow** (decision 5), and the protected-workflow
  wiring that makes ADR-0047's authority rule true again rather than aspirational.
- **The first publish itself**: build, push, sign, and write the four `.release` manifests. Until it
  happens nothing runs, and this ADR only permits it.
- **`versions.env` and the `images:` transformer** move to digests (decision 1), which closes
  SPEC-0067 AC5.
- **Egress budget** for public pulls, per the second cost.
- Whether `check-dev-images.sh` should assert the *production* references resolve, now that they will.
- Whether a second repository or mirror is warranted, per the last cost.

## Alternatives considered

- **`ghcr.io/gitfrok`, as ADR-0047 decided.** Cloud-neutral, GitHub's egress rather than ours, public
  by a visibility flag, and already the decision of record — so it costs no amendment and no
  portability. **Rejected by owner direction.** Recorded with what rejecting it costs, because the
  portability and egress lines above are entirely its advantages, and reverting is re-pointing one
  string rather than undoing work.
- **Artifact Registry kept private, with customers granted reader access per install.** Keeps the
  registry closed and makes each customer's pull auditable. Rejected: it reintroduces exactly the
  pull credential in operator manifests that ADR-0047 forbids, and it makes every BYO install a
  vendor IAM change — an onboarding step that fails quietly at `ImagePullBackOff` in a cluster we
  cannot see.
- **Publishing to both**, GHCR for customers and Artifact Registry for our own planes. Keeps
  portability and satisfies the direction. Rejected as the worst of both: two publish paths to keep
  in sync, two visibility models, and a digest that must be proven identical in both places or the
  signature chain means less than it appears to.
- **Docker Hub, which `versions.env` already names.** Rejected: it matches no decision, it holds
  nothing, and its rate limits on anonymous pulls are a poor property for a BYO install path.
- **Keeping images unpublished and building in each cluster**, as `dev-up.sh` does for Minikube.
  Rejected outright: it makes the running image unverifiable, which is the negation of ADR-0035 and
  ADR-0044, and it would put a build toolchain in a customer's cluster.
