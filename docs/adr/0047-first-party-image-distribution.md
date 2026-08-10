# ADR-0047: First-party release images are publicly pullable; trust is verified offline

- **Status:** Accepted
- **Date:** 2026-08-10
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G3 supply-chain security, G4 change governance, G9 least-privilege footprint
- **Relates to:** ADR-0011, ADR-0013, ADR-0035, ADR-0044 · **Task:** T-0021

## Context

ADR-0035 selects `ghcr.io/gitfrok/<image>` for first-party artifacts and requires
consumers to use an immutable digest. ADR-0044 keeps the signing private key in
a protected publish environment and gives agents an offline public verification
key. Neither decides whether a customer data-plane agent can pull a release
image without registry credentials.

The first protected T-0021 publishes proved the gap: the registry accepted the
publish and Cosign signed the digest, but an unauthenticated digest inspection
received `unauthorized`. A private package would require every customer cluster
to receive, rotate, and protect a GitHub Container Registry pull credential.
That credential would be a new secret-bearing control-plane-to-customer path,
would be needed before the agent can run its verifier, and conflicts with the
outbound-only and least-privilege intent of ADR-0011. It also makes the local
Minikube release manifests depend on a pull secret that is unrelated to image
authenticity.

The repository source is already public. Image confidentiality therefore adds
little value, while an unsigned or substituted public image remains unsafe;
the security property is the digest plus required offline Cosign verification,
not registry access control.

## Decision

We will publish first-party **release** images in `ghcr.io/gitfrok` as publicly
pullable OCI artifacts. Every deployment, operator, and agent still resolves a
fully-qualified immutable digest and verifies its Cosign signature against the
versioned per-environment trust bundle before application. Public visibility
does not authorize execution, bypass the PDP, or permit a release request to
provide its own key or signature.

Only protected `image-publish` workflow runs from reviewed `main` or a `v*`
release tag may publish the release tags and change package visibility. Pull
request jobs remain build-only and receive neither signing material nor package
publication authority. Development and operator manifests must not contain
GHCR pull credentials for first-party release images.

Private image distribution remains valid only for a future customer-specific
artifact whose confidentiality has a separately accepted ADR. Air-gapped
installations mirror the same signed digest under ADR-0013; a mirror changes
transport, not the required digest or verification key.

## Consequences

**Positive:** customer agents and local development can fetch a digest without
shipping registry credentials; registry availability does not become a secret
distribution problem; and supply-chain authenticity has one explicit offline
root — the Cosign trust bundle.

**Negative / costs:** image bytes, layer metadata, and SBOM attestations are
publicly discoverable. Build inputs must therefore never contain credentials or
customer data. Package visibility is a release control that CI must assert,
not a manual default.

**Follow-ups:** T-0021 makes each first-party package public only in the
protected release workflow, adds a CI assertion that the digest is anonymously
readable and verifies it with the dev trust key, then records generated digest
references in `deploy/dev/`. The operator/agent work still records the mounted
trust-bundle location and rejects an unverified release.

## Alternatives considered

- **Private GHCR packages with a shared customer pull credential** — rejected:
  turns every cluster into a custodian of a registry secret and introduces a
  credential-rotation path before the agent can verify the artifact.
- **Private package with a per-customer credential** — rejected for the MVP:
  stronger isolation does not protect a public-source image's meaningful
  secret, while account provisioning, revocation, and support become a new
  product surface.
- **Public image without digest or Cosign verification** — rejected: public
  transport is not trusted transport; ADR-0035, ADR-0044, and invariant 9
  still require exact, offline-verifiable bytes.
