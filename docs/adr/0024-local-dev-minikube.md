# ADR-0024: Local/dev environment — Minikube only (no OrbStack, no Docker Compose)

- **Status:** Accepted
- **Date:** 2026-07-19
- **Supersedes:** ADR-0021
- **Governs:** developer experience, dev/prod parity, cross-platform support
- **Relates to:** ADR-0010 (K8s portability), ADR-0013 (Helm+Operator), ADR-0023 (stack)

## Context
ADR-0021 used OrbStack + `*.orb.local`, which is macOS-only and relies on a `.local` domain
that collides with mDNS. We want one cross-platform local tool matching prod's Kubernetes
model, and no parallel Docker-Compose path to drift from.

## Decision
Local development uses **Minikube only** — **no OrbStack, no Docker Compose.**
- `minikube start` with the **`ingress`** and **`ingress-dns`** addons.
- Local wildcard domain **`*.gitsaas.test`** (`.test` is RFC 6761-reserved; avoids the
  `.local`/mDNS collision that motivated dropping `*.orb.local`).
- **TLS via `mkcert`**: generate a wildcard cert for `*.gitsaas.test`, install the local CA
  (`mkcert -install`), load the cert as a K8s TLS secret referenced by the ingress.
- Full stack (Astro SSR, Go BFF, Zitadel, Redpanda, PostgreSQL, **Valkey**, SeaweedFS) runs
  in the Minikube cluster from the same manifests as prod topology; image tags come from
  `deploy/dev/versions.env` (ADR-0023).
- The same Minikube flow is used in CI.

## Consequences
**Positive:** one cross-platform tool (macOS/Linux/Windows), no macOS lock-in; real K8s
parity; a single dev path (no Compose drift); correct reserved TLD.
**Negative:** Minikube is heavier/slower to start than OrbStack; first-run setup has a few
steps (driver choice, `ingress-dns`, `mkcert -install`) — script it in bootstrap.
**Follow-ups:** per-OS driver docs (docker/kvm2/qemu/hyperv); a `make dev-up` bootstrap
(addons + TLS secret + DNS); OIDC redirect URIs use `*.gitsaas.test`.

## Alternatives considered
- **OrbStack + `*.orb.local`** (ADR-0021) — macOS-only, `.local`/mDNS collision. Removed.
- **kind / k3d** — fine, but we standardize on one tool (Minikube) per this decision.
- **Docker Compose** — poor K8s/prod parity; explicitly excluded.
