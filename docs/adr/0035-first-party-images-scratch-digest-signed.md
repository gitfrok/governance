# ADR-0035: First-party images — `scratch` base, digest-referenced, cosign-signed

- **Status:** Proposed
- **Date:** 2026-08-08
- **Deciders:** platform
- **Governs:** G4 change governance, G9 least-privilege footprint — and the credibility of G3, which
  is scoped in `docs/agents/context.md` as a *product feature* (scanning the customer's supply chain)
  while saying nothing about our own. This ADR is about ours.
- **Relates to:** ADR-0013 (Helm + Operator — assumes images exist, does not produce them) ·
  ADR-0034 (third-party pin form — **refined for first-party artifacts, not superseded**) ·
  ADR-0023 (version floors) · ADR-0025 (one binary per plane) · ADR-0009/0011/0017 (the agent
  applies releases) · ADR-0026 (extraction adds images later) ·
  **Invariants:** 9 (signed releases only), 10 (proto v1 additive-only), 13 (reproducible pins),
  19 (one binary per plane) · **Tasks:** T-0021 (this is its AC0)

## Context

Nothing in the four repos builds a container image. No `Dockerfile`, `Containerfile`, `.ko.yaml` or
goreleaser config anywhere; no `docker build` / `buildx` / `ko build` / `kaniko` step in any CI
workflow; `deploy/dev/` deploys five infrastructure services and a busybox fixture and no plane. So
the system has never run as a deployed artifact — only under `go test` and as one composed process in
`scripts/check-policy-composition.sh`. T-0021 records how this surfaced: the policy bundle T-0003
publishes as a ConfigMap has no consumer, because there is no pod to mount it into.

ADR-0013 chose Helm + Operator for distribution and **assumes** the images already exist — it requires
mirrored images for air-gapped installs without saying who builds them or how. That is the gap.

**Two parts of this are already decided, and finding that changed the shape of this ADR.** It would
have been easy to write "should we sign our images?" as an open question. It is not one:

- **Invariant 9:** *"The agent applies only signed releases it verifies (cosign) — CP cannot push
  arbitrary code (ADR-0017)."* Unconditional.
- **`contracts/proto/agent/v1`** already carries the shape:
  ```proto
  message SignedRelease {
    string oci_ref   = 1;   // e.g. registry/gitsaas/git-rpc@sha256:...
    string digest    = 2;   // sha256 the agent MUST verify
    string signature = 3;   // cosign/DSSE sig; agent verifies vs pinned key
  }
  ```
  Proto v1 is additive-only (invariant 10), so this cannot be walked back. A **digest**, and a
  **cosign signature verified against a pinned key**, are already the contract for anything the agent
  applies.

So the real question is not *whether* first-party images are digest-referenced and signed, but whether
we build that in from the first image or retrofit it once images exist and are being consumed.
Retrofitting is strictly worse: it means a period in which the agent's own contract describes a
guarantee the artifacts do not have.

**The one genuine tension is with ADR-0034**, which requires every image reference to be a
fully-qualified, resolvable, **patch-level tag**, and which explicitly says: *"Digest pinning is
deliberately **not** decided. It defeats registry-side security rebuilds of the same tag, and that
trade deserves its own ADR rather than being smuggled in here."* That deferral was about **third-party
dependency pins** in `deploy/dev` — Postgres, Valkey, Redpanda — where an upstream may rebuild a patch
tag to carry a security fix and we want it. It was not about artifacts we build ourselves, where we
control the rebuild and would publish a new digest and a new `DesiredState.generation` anyway.

## Decision

We will build **first-party container images** as follows. "First-party" means an artifact this project
produces; third-party dependency pins remain governed by ADR-0034 unchanged.

1. **A multi-stage `Dockerfile` per image, in the repo that owns the binary.** `backend/` owns the two
   plane images, `bff/` its own, `webfrontend/` the SSR image. Not `ko`: see Alternatives.

2. **Go images build `FROM scratch`.** Statically linked (`CGO_ENABLED=0`), with only the binary, a CA
   bundle copied from the builder stage, and `USER 65532:65532`. No base image at all is the smallest
   attack surface, and it removes the base-image pin problem rather than solving it.

3. **The Node SSR image uses a patch-tagged `docker.io/library/node:<major>.<minor>.<patch>-alpine`
   base**, per ADR-0034 rule 1–3. A Node runtime cannot come from `scratch`. Stating this rather than
   implying it: two runtimes legitimately get two bases, and that is not an inconsistency to be
   embarrassed about.

4. **First-party images are referenced by digest (`@sha256:…`) and signed with cosign against a pinned
   key.** This honours invariant 9 and `SignedRelease`; it is not a new decision. A human-readable
   tag (`v<semver>` and the commit SHA) is published *alongside* the digest for legibility, but the
   digest is what any consumer — the agent, Helm values, `deploy/dev/` — resolves. Key-based rather
   than keyless/OIDC signing, because invariant 9 says *"verifies vs pinned key"* and keyless attests
   a workload identity instead.

5. **A third-party base image that publishes no patch tag must be digest-pinned.** This is the only
   place this ADR refines ADR-0034, and it refines rather than contradicts it: ADR-0034's own
   Consequences anticipate digest pinning as *"a possible later tightening rather than a rewrite."*
   Its patch-tag rule assumes upstreams publish patch tags; where one does not, a digest is the only
   reference that is not floating, and floating is what ADR-0034 exists to forbid.

6. **An SBOM per image, generated with Syft and attached as an OCI attestation, and a Grype scan in
   CI.** Syft/Grype are already the recorded stack choice (ADR-0019/0020, carried into ADR-0023).
   Initially the scan **reports**; the threshold at which it **blocks** is deliberately left to T-0021,
   because a blocking gate whose failure mode nobody has seen tends to be disabled the first time it
   is inconvenient.

7. **Registry: `ghcr.io/gitfrok/<image>`.** The org and CI are already on GitHub, so this adds no new
   trust root or credential. Air-gapped customers mirror per ADR-0013. This is unrelated to the
   roadmap's *Later / not scheduled* "registry hardening", which is a **product** feature (running a
   registry for customers), not where we push our own builds.

8. **The runtime posture is asserted by a test, not assumed:** runs as non-root, read-only root
   filesystem, no shell. On `scratch` the last is free — which is part of the argument for it.
   `deploy/dev/hello.yaml` already holds the busybox fixture to this standard; the real planes must
   not be laxer than the fixture that tests them.

9. **Four images, not three.** `dataplane-app` and `controlplane-app` (invariant 19 — one binary per
   plane), `bff`, and the `webfrontend` SSR server. **T-0021's acceptance criteria name only the first
   three**; the SSR front door is equally undeployable and its omission there is an oversight this ADR
   records rather than inherits. ADR-0026 extractions add images later — each becomes another
   `Component` in `DesiredState`, which is the shape the agent contract already anticipates.

## Consequences

**Positive.** The agent's contract stops describing a guarantee the artifacts lack — `SignedRelease`
becomes satisfiable on day one instead of after a retrofit. `scratch` gives close to zero base-image
CVE surface, which is the cheapest possible answer to a customer asking what is in the image of a
vendor selling supply-chain governance. Digest references make "which bytes are running" answerable
exactly, for the artifacts where we control rebuilds. Four small images with no shell are a smaller
G9 footprint in a customer cluster than any general-purpose base would give.

**Negative / costs.** `scratch` has no shell, no `ps`, no package manager, so `kubectl exec` debugging
is gone — the honest cost, mitigated by ephemeral debug containers rather than by weakening the image.
CA certificates and (if `time.LoadLocation` is ever used) tzdata must be handled explicitly; forgetting
the CA bundle produces x509 failures against Postgres, OIDC and the registry that look like network
faults. A signing key is now a production secret with rotation and custody obligations, and an
unsigned image must be a hard failure or the invariant is decorative. Digest references are unreadable
and must be generated, never hand-edited, which means tooling. Two base strategies (Go on `scratch`,
Node on a pinned base) is more to explain than one.

**Follow-ups.**
- Where the cosign key lives (KMS vs Actions secret), and its rotation procedure. Not decided here;
  it is a custody decision, and guessing at it would be the kind of default this ADR exists to avoid.
- The Grype threshold that blocks a build (T-0021).
- Amend T-0021's AC list to include the `webfrontend` SSR image (decision 9).
- `deploy/dev/` must resolve first-party images by digest, which `check-dev-images.sh` currently cannot
  express — it compares manifest text to `versions.env` patch tags. That check needs a first-party
  code path.
- Whether `controlplane-app` runs in `deploy/dev/` in Phase 1 or waits for Phase 3's BYO split
  (ADR-0009) — carried from T-0021's open questions, still open.

## Alternatives considered

- **`ko` instead of Dockerfiles** — rejected, and it was the closest call. `ko` is excellent for Go:
  no Dockerfile, reproducible by construction, SBOM built in, distroless by default. Rejected because
  it cannot build the Node SSR image, so adopting it means maintaining two unrelated build mechanisms
  and two mental models for "how is an image made here"; and because a `Dockerfile` is inspectable by
  the same scanners this product sells, whereas `ko`'s output is inspectable only after the fact. If
  the SSR image ever stops being ours to build, this deserves revisiting.
- **`gcr.io/distroless/static:nonroot`** — rejected, narrowly. It supplies the CA bundle, `/etc/passwd`
  and tzdata that `scratch` makes us handle by hand, and it is a genuinely good default. But it
  publishes no patch tags (`:nonroot`, `:latest`, digests), so using it forces exactly the ADR-0034
  exception in decision 5 for no security gain over `scratch` — and it adds a Google-hosted trust root
  to every image for the sake of three files we can copy.
- **`alpine`** — rejected: publishes patch tags and is convenient, but ships a shell and a package
  manager into production for debugging convenience, which is the opposite of decision 8.
- **Keyless / OIDC cosign signing** — rejected: attests the identity of the workload that built the
  artifact, which is a different and in some ways stronger claim, but invariant 9 specifies
  verification *against a pinned key*, and the agent runs in customer clusters that may have no
  outbound path to a transparency log.
- **Defer signing to Phase 3, when the agent ships** — rejected. It is the tempting sequencing, since
  nothing verifies signatures until the agent exists. But it means every image built between now and
  then is unsigned, and the retrofit lands exactly when the component that depends on it is being
  written. Signing an image is a one-line CI step; ungrounding invariant 9 for two phases is not.
- **Digest-pin everything, third-party included** — rejected: that is ADR-0034's deliberately deferred
  question, and its stated reason (defeating registry-side security rebuilds of the same tag) is sound
  for dependencies we do not build. Deciding it here would be the smuggling ADR-0034 warned about.
- **Do nothing until someone picks up T-0021** — rejected: T-0021 cannot start without this, which is
  what made it AC0.
