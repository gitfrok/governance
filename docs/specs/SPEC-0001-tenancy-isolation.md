# SPEC-0001: Tenant isolation & row-level security

- **Status:** Approved
- **Owner:** platform
- **Context(s):** all data-owning contexts (baseline)
- **ADRs:** 0003 (shared DB + RLS + cells), 0022 (per-context schema ownership)
- **Task(s):** T-0004

## Problem / context
Every persisted row belongs to exactly one tenant. Tenant data must never leak across
tenants, defended in the application layer **and** by database RLS.

## In scope
- `tenant_id` on every tenant-owned table; RLS policies keyed on the request's tenant.
- A tenant-scoping mechanism in the data-access layer (sets the RLS context per request).
- Test harness proving isolation.

## Out of scope
- Cell promotion of large tenants (later); cross-context data sharing (via API/events only).

## Contracts touched
None (internal). Cross-context data is never read directly (ADR-0022).

## Data owned
Each context owns its schema; RLS applies within each. No cross-context table access.

## Acceptance criteria (each becomes a test)
- [ ] AC1: A query under tenant A cannot read or write any row owned by tenant B (RLS denies).
- [ ] AC2: The app layer sets the tenant context on every request; a missing tenant context
      results in **deny** (no rows), not a full-table read.
- [ ] AC3: Attempting a cross-tenant write is rejected and emits an audit event (ADR-0007).
- [ ] AC4: A migration lint fails if a new tenant-owned table lacks `tenant_id` + an RLS policy.

## Governance mapping (G1–G9)
| Objective | How |
|---|---|
| G1 isolation | RLS + app scoping; AC1/AC2 prove no cross-tenant access |
| G2 least privilege | deny-by-default on missing tenant context (AC2) |
| G5 auditability | cross-tenant attempts are audited (AC3) |

## Non-functional
RLS overhead acceptable (< a few % on hot paths); scoping is O(1) per request.

## Open questions / assumptions
- Assumes a single logical Postgres now (ADR-0003); cell split is a later ADR.
