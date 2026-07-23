# ADR-0021: Local/dev environment — OrbStack Kubernetes with `*.orb.local` automatic TLS

- **Status:** Superseded by ADR-0024
- **Date:** 2026-07-19
- **Governs:** developer experience, dev/prod parity
- **Relates to:** ADR-0010 (K8s portability), ADR-0013 (Helm+Operator), ADR-0020 (stack)

## Context
We want local development to mirror the Kubernetes-native production model with minimal
setup and real HTTPS, so the inner loop matches how the product actually runs.

## Decision
Use **OrbStack's built-in Kubernetes** for local/dev. Expose services under **`*.orb.local`**
with **automatic TLS** (OrbStack issues and locally-trusts certs). The full stack (Astro SSR,
Go BFF, Zitadel, Redpanda, Postgres, Redis, SeaweedFS) runs in the OrbStack cluster using the
same manifests as production topology.

## Consequences
**Positive:** near-zero-config local Kubernetes + HTTPS; high dev/prod parity; fast Mac-native
performance.

**Negative / caveat:**
- **OrbStack is macOS-only.** Linux/Windows contributors and **CI** need a fallback: **kind**
  or **k3d** with a locally-trusted wildcard cert via **mkcert** (e.g. `*.gitsaas.local`), or
  nip.io/dnsmasq for DNS. Keep manifests provider-neutral (per ADR-0010) so both paths work.
- Zitadel and OIDC **redirect/callback URLs** and any hard-coded hostnames must be
  **per-environment configurable** (`*.orb.local` locally, `*.gitsaas.local` under kind/k3d,
  real domains in prod).

**Follow-ups:** provide and document the kind/k3d + mkcert fallback for non-Mac/CI; centralize
env-specific hostnames + OIDC redirect URIs in config.

## Alternatives considered
- **Docker Compose** — simpler but poor K8s/prod parity.
- **minikube/kind alone** — cross-platform but manual TLS/DNS (this is our non-Mac fallback).
- **Tilt / Skaffold** — complementary inner-loop tooling; can layer on top of OrbStack/kind.
