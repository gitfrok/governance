# ADR-0022: Modular architecture — high cohesion, low coupling

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** maintainability, evolvability, parallel development; isolates all of G1–G9
- **Refines:** ADR-0003 (data ownership); **Relates to:** ADR-0020 (thin BFF, contracts)

## Context
The system spans many subsystems. To keep it maintainable, testable, and workable by
multiple teams/agents in parallel with small blast radius, we organize around **bounded
contexts** that are internally cohesive and externally minimally coupled.

## Decision

### Bounded contexts (each cohesive; owns its domain + data)
- **Data plane:** Identity & Access, Repository/Git, Code Review, CI/CD, Security/Findings,
  Registry, Code Search, Policy (PDP), Audit.
- **Control plane:** Tenant/Org, Billing & Metering, Release/Fleet (+ Agent Gateway).
- *Policy* and *Audit* are provider/sink contexts: others depend on them; they depend on none.

### Hexagonal (ports & adapters) inside every context
`domain` (pure — no infra imports) → `app` (use cases via port interfaces) →
`adapters` (inbound: gRPC/HTTP; outbound: Postgres, Redpanda, SeaweedFS, OPA, Zitadel) →
`cmd` (wiring/main). **Dependencies point inward only.**

### Contracts are the only shared surface
All cross-context calls go through `contracts/` (gRPC protos + Redpanda event schemas).
**No context imports another context's internal packages.** Anti-corruption at boundaries;
never leak another context's model. Prefer **event choreography** over synchronous calls
(e.g. Repository emits `RefUpdated` → CI, Search, Audit react independently).

### Data ownership (refines ADR-0003)
Each context **owns its schema**; **no cross-context database access.** A shared *physical*
Postgres is still fine, but ownership is logical (schema-per-context), and tenant RLS still
applies within a context. Cross-context data is obtained via API or via event-fed **local
read-model projections** — never by reading another context's tables.

### Thin BFF (ADR-0020)
The Go BFF only aggregates gRPC and shapes responses — **no business logic** — so the UI
stays decoupled from domain internals.

### Deployment: boundaries are logical
Contexts needing independent scaling/isolation run as **separate services now** (Git tier,
CI runners, agent, operator). Other app-layer contexts **start co-located as a modular
monolith** with enforced boundaries and are **split into services later** — the contracts
are identical either way. Modular-monolith-first avoids premature distributed coupling.

### Enforcement
Boundary/dependency rules are checked in CI (import-linter / arch tests). Domain packages
are forbidden from importing infra or adapters.

## Consequences
**Positive:** parallel work with low merge/blast radius; adapters are swappable (e.g.
SeaweedFS ↔ cloud S3) without touching domain; domain is unit-testable in isolation;
contracts let contexts evolve independently.
**Negative:** more upfront structure/boilerplate; event-driven flows are harder to trace
(needs good observability + an event catalog); discipline required to not "reach across."
**Follow-ups:** pick the boundary-enforcement linter; define the event catalog + naming
conventions; decide which app-contexts start co-located vs separate.

## Alternatives considered
- **Layered-by-technical-role** (controllers/services/repositories spanning all features) —
  low cohesion, coupling grows with the codebase.
- **Full microservices from day one** — distributed + operational coupling before it's
  warranted; rejected as default in favor of modular-monolith-first.
