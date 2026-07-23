# ADR-0010: Target GKE/EKS/AKS via a Kubernetes-API-first portability layer

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G7 residency, portability

## Context
The data plane must run on the three major managed Kubernetes offerings despite their
differing object storage, identity, ingress, and KMS primitives.

## Decision
**Depend on Kubernetes APIs, not cloud APIs**, wherever possible. Isolate unavoidable
cloud-specific bits behind small per-cloud drivers: object storage (GCS/S3/Blob),
keyless identity (Workload Identity / IRSA / Entra Workload ID), ingress (Gateway API
or nginx), storage classes, and KMS (external-secrets + customer keys). Maintain a
per-cloud conformance test suite.

## Consequences
**Positive:** one product across three clouds; avoids lock-in; enables residency.
**Negative:** lowest-common-denominator constraints; large test matrix; slower velocity.
**Follow-ups:** conformance matrix as a living checklist.

## Alternatives considered
- **Single cloud, use native services** — faster to build, but excludes most enterprise buyers.
