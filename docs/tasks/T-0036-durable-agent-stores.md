# T-0036: Durable agent stores — enrolment-token store and data-plane registry

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-19 (durable control-plane stores)
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0042-durable-agent-residency-stores.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0062, 0003, 0023, 0025, 0055
- **Owner:** unassigned

## Goal

Make PR-20's enrolment state a property of the platform rather than of a process: Postgres adapters
for the enrolment-token store and the data-plane registry behind the ports T-0030 left in memory, so
a spent token stays spent, a revocation still refuses, and the registry's staleness machine survives
a control-plane kill-and-restart (ADR-0062).

## Acceptance criteria (test-first)

SPEC-0042 AC1, AC2, and the agent-module half of AC5 (AC3, AC4 and the residency tables are
T-0037's):
- [ ] AC1: token spend and revocation survive a control-plane kill-and-restart — a token spent before
      the restart is refused when replayed after it, including retry-after-partial-enrolment
      (SPEC-0038 AC1); a revocation issued before the restart still refuses the next connection.
- [ ] AC2: the registry staleness machine — NEVER_CONNECTED, CONNECTED, STALE, REVOKED — recomputes
      from durable liveness records after a restart, exactly as distinguishable as before it;
      staleness never derives from process uptime and a stale data plane is never rendered healthy
      (SPEC-0038 AC8).
- [ ] AC5 (agent tables): additive, rollback-tested up/down migrations under the agent module's own
      `internal/adapters/postgres/migrations`; RLS tenant scoping with no un-tenant-scoped query path
      (ADR-0003); enrolment tokens persist as one-way hashes only — never raw (SPEC-0038 AC2, now
      the store as well as the logs).

## Tests to write first

Per SPEC-0042 § Test plan:
- integration: every AC against a real Postgres harness — the in-memory fakes stay for the fast
  suites; durability is proven against the real adapter, not the double.
- chaos-restart: spend → kill −9 → restart → replay (AC1); connect → kill → restart → read registry
  states (AC2).
- migration up/down per module, plus an RLS assertion query per new table (AC5).
- `go test -race` across the new adapters for concurrent spend paths.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — RLS, tenant scoping, audit.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race` — including the real-Postgres harness above.

## Notes / open questions

The in-memory fakes stay behind the same ports as test doubles, not as a deployment posture
(ADR-0062 decision 1). Store growth is unmetered here and stays on ADR-0055's follow-up — durability
is not held hostage to the meter. Sequencing: EP-19's first task; T-0037 repeats this task's
adapter/migration pattern for the residency store and the pack assembly that reads it.
