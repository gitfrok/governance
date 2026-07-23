# ADR-0003: Multi-tenancy via shared Postgres + row-level security, with cell escalation

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G1 tenant isolation

## Context
Tenant = organization. We need strong isolation without paying dedicated-infra cost
for every small tenant.

## Decision
Default to a shared Postgres with `tenant_id` on every row and **row-level security**.
Enforce tenant scope in the app *and* the PDP (defense in depth). Very large or
regulated tenants are promoted to dedicated databases/clusters (a "cell" model).

## Consequences
**Positive:** cost-efficient at scale; clear upgrade path for big tenants.
**Negative:** RLS discipline required; a query bug could risk isolation — mitigated by
the second PDP check and isolation tests in CI.
**Follow-ups:** CI test that asserts cross-tenant queries return nothing.

## Alternatives considered
- **DB-per-tenant everywhere** — safest but expensive/operationally heavy for small tenants.
- **Schema-per-tenant** — awkward at thousands of tenants.
