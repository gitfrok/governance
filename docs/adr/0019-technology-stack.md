# ADR-0019: Technology stack

- **Status:** Superseded by ADR-0020
- **Date:** 2026-07-19
- **Governs:** all objectives (enables G1–G9); operability
- **Relates to:** ADR-0004/0005/0006/0007/0008/0010/0011/0012/0013/0014/0015/0017

## Context
We need a stack that lets a small team reuse battle-tested, cloud-native components
rather than build core infrastructure from scratch, and that fits the BYO / multi-cloud
Kubernetes model. Most of the components we depend on (Git RPC, controller-runtime, gRPC,
OPA, KEDA, Zoekt) are Go-native, which pulls the backend toward Go.

## Decision
Adopt a **Go-first backend, React/TypeScript frontend, Kubernetes-native platform**:

**Core**
- Backend language: **Go** (Git tier, CI control plane, agent, operator, services).
- Frontend: **React + TypeScript + Tailwind + Radix** (design system per ADR-0015),
  TanStack Query, command palette; Vite SPA behind a Go BFF (Next.js if SSR is wanted).

**Git & storage** (ADR-0004/0016)
- Go Git-RPC tier (git plumbing / libgit2, Gitaly-style); **Raft** coordination for the
  sync-1-replica quorum + failover. Fast per-cloud block volumes for repos.
- **S3-compatible object storage** for LFS, artifacts, registry blobs.

**Data & messaging** (ADR-0003)
- **PostgreSQL** with row-level security; **CloudNativePG** for in-cluster BYO installs.
- **Redis** (cache/sessions); **NATS JetStream** for CI queue + event bus (Kafka only if
  heavy durable streaming is later required).

**CI/CD** (ADR-0005/0012)
- Custom Go control plane; jobs on Kubernetes with **gVisor RuntimeClass** (Kata optional);
  **KEDA + cluster autoscaler** for the runner fleet.

**DevSecOps scanners** (G3) — best-of-breed OSS in pipelines, normalized into one vuln store:
- **Trivy**, **Semgrep**, **Gitleaks**, **OWASP ZAP**, **Syft/Grype** (SBOM).

**Governance plumbing**
- Policy: **OPA/Rego** (ADR-0006). Code search: **Zoekt** (ADR-0014).
- Registry: **CNCF Distribution** or **Zot** (OCI). Audit: append-only hash-chained Postgres
  partition exported to WORM object storage (ADR-0007).

**Identity** (G2) — **Zitadel** (Go, multi-tenant, OIDC/SAML/SCIM) or Ory; Keycloak if buyers expect it.

**Agent & platform** (ADR-0010/0011/0013/0017)
- Agent/Operator: **Go + controller-runtime/Kubebuilder**; **gRPC over mTLS** with
  **SPIFFE/SPIRE**; **cosign/Sigstore** for signed-releases-only.
- Infra: **Terraform/OpenTofu** (per-cloud modules), **Argo CD** GitOps, **Gateway API**
  (Envoy Gateway/Contour), cert-manager + external-dns + external-secrets.

**Ops & billing**
- **OpenTelemetry → Prometheus/Grafana/Loki/Tempo** (separate from the audit log).
- **Stripe** + internal metering fed by the agent's `UsageSample` (ADR-0008).

## Consequences
**Positive:** maximum reuse of proven cloud-native components; single-language backend eases
hiring around the core; static Go binaries suit the BYO agent; portable across GKE/EKS/AKS.
**Negative:** Go is less ergonomic for rich app CRUD than Rails/Phoenix; several moving parts
to operate; team must be comfortable in Go for the hard subsystems.
**Follow-ups:** confirm against team expertise (see knob below); pin versions; supply-chain
policy for third-party scanners.

## The knob left for you
- **Team expertise fork:** if you are a Rails/TS or Elixir shop, keep Postgres/React/K8s but
  let the *app* layer be **Rails or Phoenix**, reserving **Go** for the Git tier, agent,
  operator, and CI control plane (where ecosystem fit is non-negotiable). Record a superseding
  ADR if you take this path. **Rust** only for the Git-RPC core or sandbox supervisor if you
  have the depth.

## Alternatives considered
- **Rails/Phoenix monolith throughout** — great app velocity, but poor fit for the Git RPC,
  operator, agent, and CI-isolation layers that dominate this product's risk.
- **Node/TypeScript backend** — unifies language with frontend, but weakest ecosystem fit for
  the Git/K8s/policy core.
- **Kafka + Java platform** — heavier than needed; NATS covers our queue/eventing.
