# T-0004: Tenancy + RLS baseline

- **Status:** Done (2026-08-06) — AC1–AC4; two limits recorded below
- **Phase / Epic:** 0 / EP-2
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0001-tenancy-isolation.md
- **ADRs:** 0003, 0022, 0007
- **Owner:** unassigned

## Goal
Implement SPEC-0001: tenant_id everywhere + RLS + deny-by-default scoping.

## Acceptance criteria (test-first)
- [x] AC1–AC4: exactly the acceptance criteria in SPEC-0001. Implemented in backend `a22a8e2` (#7)
  and verified against a real Postgres with RLS enforced — an in-memory fake would only have proved
  that a fake denies things.

## Tests to write first
- policy/isolation (mandatory): cross-tenant read/write returns nothing / is rejected.
- unit: tenant-scoping helper sets/*requires* context.
- integration: RLS policies on real Postgres 18.
- boundary: migration lint fails on a tenant table lacking tenant_id + RLS.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.

## Implementation record

| Repo | Merged | What |
|---|---|---|
| backend | `a22a8e2` (#7) | `platform/tenancy` (context carrier), `platform/db` (scoped transactions), `platform/audit` (AC3 event), `internal/arch` migration lint (AC4), `platform/db/migrations/0001_tenancy_baseline.sql` |

### How each AC is proven

- **AC1** — a tenant cannot read or write another's rows. Asserted in both directions so neither can
  pass vacuously: A cannot see B's row *and* B can see its own; a cross-tenant UPDATE affects zero
  rows *and* B's data is verified unchanged; a forged INSERT is refused by `WITH CHECK`.
- **AC2** — denial has two independent halves, and both are tested. `InTx` returns `ErrNoTenant`
  **before touching Postgres** (the callback never runs), and separately the database returns **no
  rows** when `app.tenant_id` is unset. The second is what survives application code that bypasses
  `platform/db` entirely.
- **AC3** — a write refused by an RLS policy (SQLSTATE 42501) publishes `TenantIsolationViolation` on
  the in-process bus. Auditing observes enforcement and never gates it: with no bus configured the
  write is still rejected, which has its own test.
- **AC4** — the migration lint requires `tenant_id`, `ENABLE` **and** `FORCE` row-level security, and
  a policy, per tenant-owned table. Four fixtures prove each rule fires; one proves clean SQL is not
  flagged.

### Three decisions a reviewer should know

- `pgxpool` is **wrapped, not embedded**, so no caller can reach an unscoped `Query`/`Exec`. The one
  exception is `InTxUnscoped(ctx, reason, fn)`, which refuses an empty reason.
- `SET LOCAL`, not `SET` — otherwise a pooled connection carries one request's tenant to the next
  borrower. Tested, because no per-connection test would catch it.
- `db.Open` **refuses a SUPERUSER or BYPASSRLS role**. Without that, running the suite as `postgres`
  makes every isolation test pass against a database enforcing nothing — the most dangerous possible
  false green. Verified against a real superuser DSN.

### Two limits, recorded rather than left to be found

1. **AC3 cannot see the silent case.** RLS makes another tenant's rows *invisible*, so a cross-tenant
   UPDATE or DELETE matches nothing and succeeds with zero rows affected — there is no error to
   detect and nothing to audit. Only `WITH CHECK` violations surface. Inherent to RLS, not an
   implementation gap; auditing the silent case would require callers to declare intent at every
   site, which SPEC-0001 does not ask for.
2. **The audit routing key is provisional.** `gitsaas.events.audit.v1.TenantIsolationViolation` has
   no counterpart in `contracts/events`, so unlike every other event here it has no parity test.
   **T-0006 owns that contract and must adopt or rename it** — nothing subscribes today, so the
   change is free now and expensive later.
   **Resolved (recorded here 2026-08-16): T-0006 took the rename.** `contracts/events/audit/v1`
   carries one generic `AuditEvent`, the isolation violation travels on it as the action
   `tenant.isolation.violation`, and `platform/auditsink` subscribes and routes it (backend@be0d108).
   T-0006's exit record — *"T-0004's provisional routing key is resolved — renamed"* — is the
   authority; this pointer exists so the follow-up is not read as open.

### Follow-ups (not blocking this task)

- **CI does not run AC1–AC3.** The integration tests skip without `TEST_DATABASE_URL`, so backend CI
  covers build, vet and the arch gates but not the isolation proofs. A Postgres service container in
  the backend workflow would close that.
- **Nothing applies the migrations.** ~~The dev cluster still builds its schema from
  `deploy/dev/postgres.yaml`, so `0001_tenancy_baseline.sql` duplicates that init SQL until a
  migration runner exists. Two sources of schema truth is a drift risk that should not outlive T-0006.~~
  **Closed (recorded 2026-08-16).** `scripts/dev-provision.sh` applies ALL backend migrations —
  tenant, audit, identity, policy, security, agent, residency — as its first step, idempotently, and
  `make dev-provision` is the documented path. The runner exists; the schema has one source.
