# Test-Driven Development (TDD)

**Red → Green → Refactor**, always, derived from the spec's acceptance criteria.

## Rules
1. Write a failing test first (RED). No production code without a failing test that needs it.
2. Write the minimum code to pass (GREEN).
3. Refactor with tests green — **without** crossing HCLC boundaries (ADR-0022).
4. A bug fix starts with a failing test that reproduces it.

## Test taxonomy
- **Unit (domain):** pure domain logic, no infra. Fast, the majority. Go: table-driven.
- **Contract:** gRPC services and Redpanda events against `contracts/` schemas
  (producer/consumer). Guards low coupling.
- **Integration (adapters):** real Postgres/Valkey/Redpanda/SeaweedFS via the dev cluster
  or ephemeral containers.
- **Boundary / arch tests (mandatory):** enforce invariants 14–18 (no cross-context imports,
  `domain` imports no infra, etc.). Fail the build on violation.
- **Policy + isolation (mandatory):** prove deny-by-default and that cross-tenant access
  returns nothing (invariants 1–4).
- **E2E (thin):** a few critical user paths via the SSR app (Playwright); web unit via Vitest.

## Guidance
- Test behavior, not implementation. Name tests by behavior (`Test_<unit>_<condition>_<expect>`).
- Keep the domain layer trivially unit-testable (that's the point of hexagonal).
- Coverage is a signal, not a target — but domain + policy/isolation paths must be covered.
