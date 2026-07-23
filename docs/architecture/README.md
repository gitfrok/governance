# Architecture overview

Multi-tenant Git SaaS with a **control plane** (we host: billing, org metadata, policy
authoring, dashboards, release/fleet) and a **data plane** in the customer's Kubernetes
(repos, CI, registry, scanners, data), joined by an **outbound-only agent** over gRPC/mTLS.

The differentiators: a **unified security/governance UX** (ADR-0015) and **flat-rate
pricing** made safe by fair-use + BYO (ADR-0008/0009).

## Design principles
- **Governance-driven** — governance is both the operating discipline and the product
  (ADR-0002); traces to objectives **G1–G9** (see `../agents/context.md`).
- **High cohesion / low coupling** — bounded contexts + hexagonal ports/adapters; the only
  shared surface is `contracts/` (ADR-0022).
- **Modular monolith now, service-based later** — the app layer is one monolith binary per plane
  (ADR-0025) and evolves to a few coarse services on triggers (ADR-0026), never microservices.

## Documents
- `01-governance-driven-design.md` — the governance-first method.
- `02-git-saas-system-design.md` — full system design (storage, CI, security, pricing, UX).
- `03-byo-kubernetes.md` — BYO / multi-cloud deployment (control/data-plane split, portability).

> These are **narrative context**. The binding **decisions** are the ADRs in `../adr/`
> (index: `../adr/README.md`). Where they differ, the ADR wins.
