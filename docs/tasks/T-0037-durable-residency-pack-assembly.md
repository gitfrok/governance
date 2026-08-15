# T-0037: Durable residency declarations and evidence-pack assembly from durable projections

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-19 (durable control-plane stores)
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0042-durable-agent-residency-stores.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0062, 0003, 0023, 0025, 0055
- **Owner:** unassigned

## Goal

Make PR-22's declaration state outlive the process that holds it: the residency declaration store as
effective-dated Postgres rows with retained history, and evidence-pack residency assembly that reads
durable projections only — a pack assembled after a restart cites what one assembled before it would
(ADR-0062). This closes the recorded limit T-0033's exit carries verbatim: the declarations the pack
cites vanish on restart while the audit trail that recorded them stays.

## Acceptance criteria (test-first)

SPEC-0042 AC3, AC4, and the residency-module half of AC5:
- [ ] AC3: declarations are durable and effective-dated — a declare or replace appends a new row and
      retains history; the declaration in force at any point in a range is answerable from the store;
      the pack's residency section (SPEC-0040 AC4–AC6) is reproducible from the store after a
      restart.
- [ ] AC4: evidence-pack assembly structurally cannot reach in-process stores — an architecture
      fitness test asserts no assembly path reads process memory; the property is enforced by
      construction, not by review.
- [ ] AC5 (residency tables): additive, rollback-tested up/down migrations under the residency
      module's own `internal/adapters/postgres/migrations`; RLS tenant scoping with no
      un-tenant-scoped query path (ADR-0003).

## Tests to write first

Per SPEC-0042 § Test plan:
- chaos-restart: declare → kill → restart → assemble pack — the pack assembled after the restart
  cites the declaration in force during the range (AC3).
- architecture fitness test over the pack-assembly path (AC4).
- migration up/down per module, plus an RLS assertion query per new table (AC5).
- `go test -race` on the concurrent declare/replace paths.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — evidence and tenancy.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness (AC4's test
  lives here), policy + tenant-isolation, `go test -race` — against a real Postgres harness.

## Notes / open questions

Depends on T-0036 (M1 ordering): the adapter/migration pattern lands once there, then repeats here.
SPEC-0043's assumption makes this store a prerequisite for T-0038's wire surface — a surface over a
volatile store would re-create the problem ADR-0062 exists to close. Migration of existing tenant
data across a residency change stays undesigned and out of scope (SPEC-0040's open question).
