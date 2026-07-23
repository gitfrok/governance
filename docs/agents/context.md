# Context — condensed architecture (agents start here)

## Product
Multi-tenant Git SaaS: repos + MR review + issues + CI/CD + registry + DevSecOps
scanners + audit/compliance. Differentiators: **unified security/governance UX**
(ADR-0015) and **flat-rate pricing** made safe by fair-use + BYO (ADR-0008/0009).

## Topology (ADR-0009/0010/0011)
- **Control plane (we host, multi-tenant):** billing, org/user metadata, policy authoring,
  dashboards, license/release service.
- **Data plane (customer's GKE/EKS/AKS, single-tenant):** app services, Git tier, CI
  runners, registry, scanners, their data.
- Connected by an **outbound-only Go agent** over one gRPC bidi stream, mTLS
  (SPIFFE IDs), desired-state reconcile, **signed releases only** (ADR-0017;
  schema: `contracts/proto/agent/v1/agent.proto`).

## Request path (ADR-0020)
`browser → Astro+React SSR on Node (thin proxy) → Go BFF → gRPC → Go domain services`

## Key subsystems → owning ADR
| Subsystem | Decision | ADR |
|---|---|---|
| Multi-tenancy | shared Postgres + RLS + tenant_id everywhere; cells for big tenants | 0003 |
| Git storage | Git-RPC service; sharded nodes; app never touches disk | 0004 |
| Git durability | ack after primary + 1 sync replica; async fan-out; only in-sync promotes | 0016 |
| Dual loss | fail-safe read-only; audited operator force-promote only | 0018 |
| CI isolation | one ephemeral sandbox/job; gVisor RuntimeClass default on BYO | 0005, 0012 |
| Policy | OPA/Rego at PEP/PDP, deny-by-default, policy repo | 0006 |
| Audit | append-only, hash-chained, no delete path | 0007 |
| Search | Zoekt-style index, permission-filtered results | 0014 |
| Packaging | Helm chart + Operator (CRDs), air-gap capable | 0013 |
| Stack | Go, Astro SSR, Zitadel, Redpanda, PostgreSQL 18, Valkey, SeaweedFS | **0023** |
| Dev env | Minikube only (ingress+ingress-dns) + *.gitsaas.test mkcert TLS | 0024 |

## Governance objectives (referenced everywhere as G1–G9)
| ID | Objective |
|----|-----------|
| G1 | Tenant isolation — no cross-tenant data/compute leakage |
| G2 | Least privilege — RBAC/ABAC, scoped tokens, deny-by-default |
| G3 | Supply-chain security — SAST/DAST/deps/secrets/container scanning (product feature) |
| G4 | Change governance — protected branches, approvals, policy-as-code |
| G5 | Auditability — immutable audit trail (product feature) |
| G6 | Compliance frameworks — controls + evidence export |
| G7 | Data residency — tenant data/compute pinned to region/cloud |
| G8 | Cost governance — fair-use envelopes keep flat-rate solvent |
| G9 | Least-privilege footprint — the agent in customer clusters is minimal + auditable |

## Module architecture — ADR-0022 (HCLC) · ADR-0025 (modular monolith) · ADR-0026 (SBA target)
**Bounded contexts** (cohesive, own their domain + data):
- Data plane: Identity&Access, Repository/Git, Code Review, CI/CD, Security/Findings,
  Registry, Code Search, Policy (PDP), Audit.
- Control plane: Tenant/Org, Billing&Metering, Release/Fleet (+ Agent Gateway).

**Hexagonal per context:** `domain` (pure) → `app` (use cases via ports) →
`adapters` (gRPC/HTTP in; pg/redpanda/seaweedfs/opa/zitadel out) → `cmd` (wiring).
Dependencies point inward only.

**Coupling rules:** cross-module in-process only via the target's `api` package or the in-process
bus; cross-process only via `contracts/` (gRPC + events); no cross-module DB access (each owns its
schema — refines ADR-0003); prefer events over sync calls; thin BFF.

**Suggested layout:**
```
/modules/<ctx>/
  api/                                       public in-process surface (types+interfaces) — ONLY entry
  internal/{domain,app,adapters}/            Go-unimportable across modules (hexagonal, inward deps)
/cmd/dataplane-app/  /cmd/controlplane-app/  one modular-monolith binary per plane (wire modules)
/contracts/{proto,events}/<ctx>/v1/          cross-PROCESS surface (for the separate processes)
/platform/{ids,bus,telemetry}/               shared kernel incl. the in-process event bus
/bff/  /web/                                 Go BFF (aggregation only) + Astro/React SSR
/agent/  /operator/  /deploy/  /docs/        separate processes by necessity + infra/docs
```
**Deployment (ADR-0025):** the app layer ships as **one modular-monolith binary per plane**
(`cmd/dataplane-app`, `cmd/controlplane-app`); modules are packages that talk only via each other's
`api` package or the in-process bus. Separate processes **by necessity**: `git-storaged` (ADR-0004),
CI runners (ADR-0005/0012), the agent (ADR-0011), the operator (ADR-0013).
**Target (ADR-0026):** evolve to **service-based architecture** — a few coarse services, shared
Postgres *cluster* with schema-per-context — extracting a module into a service only when a
fitness-function trigger fires (scaling, isolation/compliance, SLO/cadence, build-time).

**Repository topology (ADR-0027/0028):** source is split into a **super-repo + 4 git submodules**
— `governance` (ADRs, specs, `contracts/`, `policies/`, process, agent rules), `backend` (the Go
modular monolith), `bff`, `webfrontend`. One-way direction: `webfrontend → bff → backend →
governance(contracts)`; governance depends on nothing. Details: `../architecture/04-repository-topology.md`.
