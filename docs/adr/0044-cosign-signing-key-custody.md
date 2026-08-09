# ADR-0044: Cosign signing-key custody and rotation for first-party images

- **Status:** Accepted
- **Date:** 2026-08-10
- **Deciders:** platform
- **Governs:** G3 supply-chain security, G4 change governance, G9 least-privilege footprint
- **Relates to:** ADR-0011, ADR-0013, ADR-0035 · **Task:** T-0021

## Context

ADR-0035 requires first-party images to be published to `ghcr.io/gitfrok`, consumed by digest, and signed with key-based cosign.
It deliberately leaves key custody and rotation undecided. That blocks a real digest-pinned dev-plane deployment.
Unsigned publication and a repository-held private key both make invariant 9 decorative.
The data-plane agent can run without reliable transparency-log connectivity, so ADR-0035 rejects keyless/OIDC.
The key must be usable by publishing CI, unavailable to pull-request code, and verifiable offline by an agent or operator.

## Decision

We will keep one active ECDSA cosign private key in a GitHub organization Actions secret scoped to a protected `image-publish` environment.
Only reviewed workflow runs from protected `main` and release tags may access that environment.
Pull-request workflows build and posture-test images but cannot publish or sign them.

The signing workflow signs the pushed immutable OCI digest, attaches the signature to the same registry, and records that digest in generated deployment/release manifests.
It never logs a key, passphrase, or plaintext signing payload.
The public verification key is a non-secret, versioned, per-environment operator/agent trust-bundle artifact.
It is not embedded in images or accepted from a release request.

Rotation creates a second protected-environment key and publishes its public key beside the current one.
Consumers accept both only during an explicit overlap.
CI signs new images with the new key; after every active release is re-signed or expired, remove the old public key and Actions secret.
On compromise, revoke the old public key immediately, block promotion, and re-sign every still-eligible digest.

## Consequences

**Positive:** GitHub remains the single publishing trust boundary; private material stays out of source, PR workflows, images, and customer clusters; verification works offline; rotation has a two-key safety window.

**Negative / costs:** Actions becomes a signing-key custodian; environment protection and secret access need administrator setup; compromise requires release re-signing; local developer images are unsigned and cannot represent an agent-applied release.

**Follow-ups:** T-0021 adds protected publish/sign CI, trust-bundle wiring, generated digest dev manifests, and verification tests.
The operator/agent work records the exact trust-bundle location and verifies a signature before application.

## Alternatives considered

- **Cloud KMS per GKE/EKS/AKS provider** — rejected: it couples portable publishing to three provider IAM/key APIs before a control-plane provider is selected.
- **Repository secret available to every workflow** — rejected: pull-request code could exfiltrate a production signing key.
- **Keyless/OIDC cosign** — rejected by ADR-0035: customer agents may not reach its transparency log.
- **Unsigned CI images until the agent exists** — rejected: it contradicts ADR-0035 and invariant 9.
