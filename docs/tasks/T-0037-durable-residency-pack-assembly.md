# T-0037: Durable residency declarations and evidence-pack assembly from durable projections

- **Status:** Done (2026-08-15) — backend@816cb30; SPEC-0042 AC3, AC4 and AC5 (residency half)
  proven against a real-Postgres harness with zero skips; closes T-0033's carried in-memory-store
  limit; recorded limits below
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
- [x] AC3: declarations are durable and effective-dated — a declare or replace appends a new row and
      retains history; the declaration in force at any point in a range is answerable from the store;
      the pack's residency section (SPEC-0040 AC4–AC6) is reproducible from the store after a
      restart.
- [x] AC4: evidence-pack assembly structurally cannot reach in-process stores — an architecture
      fitness test asserts no assembly path reads process memory; the property is enforced by
      construction, not by review.
- [x] AC5 (residency tables): additive, rollback-tested up/down migrations under the residency
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

## Exit record (2026-08-15)

Implemented test-first and merged to backend main at **816cb30** (commits **ee70ea6** effective-dated
declaration migrations up+down, **6ade07d** durable declaration store over Postgres + chaos proofs,
**6f27817** pack-assembly architecture fitness — no reach to in-process stores, **816cb30**
composition-root swap to the durable declaration store). Every proof below ran with `-race` against
the **real-Postgres harness** at `127.0.0.1:15432` with **zero skips**.

**SPEC-0042 AC3, AC4, AC5 (residency half) — one line of proof each:**

- **AC3** — declarations are durable and effective-dated, and the pack's residency section is
  reproducible from the store across a kill −9/restart: `TestAC3_DeclarationSurvivesKillRestart`,
  `TestAC3_EffectiveDateRangeSemantics`, `TestAC3_ConcurrentDeclareReplace` (under `-race`), and
  `TestAC3_PackCitesSameDeclarationAcrossKillRestart` — the pack digest is identical across the
  kill −9/restart.
- **AC4** — pack assembly structurally cannot reach in-process stores, enforced by construction and
  asserted by the real import-closure gate `TestPackAssemblyReachesNoInProcessStores`, kept honest
  by the fixture triad `TestPackAssemblyCatchesADirectMemoryReach`,
  `TestPackAssemblyCatchesAnIndirectMemoryReach` and `TestPackAssemblyAcceptsDurableReads`.
- **AC5 (residency tables)** — additive, reversible migrations under the residency module's own
  migrations directory with RLS forced and no unscoped path:
  `TestAC5_UpAndDownMigrationsAreReversible`,
  `TestAC5_RLSEnabledForcedWithTenantIsolationPolicy`,
  `TestAC5_RLSIsolatesTenantsAtTheSQLLayer`, `TestAC5_NoUnscopedPathExists` (zero
  `SECURITY DEFINER`, zero unscoped call sites in the module), plus the migration lint tests
  including `HasNoExemption` and `IsEffectiveDatedAndAppendOnly`.

**Closes T-0033's carried limit.** T-0033's exit recorded verbatim: *The declaration store is
in-memory. It is lost on a control-plane restart; the audit trail remains durable, so the declaration
is reconstructable from the record, but the live store does not survive the restart.* That limit is
now closed: the residency declaration store is effective-dated Postgres rows with retained history,
and pack assembly reads durable projections only, so a pack assembled after a restart cites what one
assembled before it (ADR-0062) — proven by `TestAC3_PackCitesSameDeclarationAcrossKillRestart`. The
closure is recorded here and in the backlog, the same shape T-0026 used to discharge T-0018's AC19
and T-0036 used for the agent stores.

**Recorded limits (write the limit down):**

- **CI skips these proofs without `TEST_DATABASE_URL`.** The real-Postgres harness is a local
  run; the CI lane runs the in-memory fakes and skips the durability suite when no database is
  provided — the same recorded shape as Phase 3's integration suites (HANDOFF known gap 5), carried
  verbatim from T-0036. The proofs above are real but rest on this local run.
- Migration of existing tenant data across a residency change stays undesigned and out of scope,
  exactly as the task and SPEC-0040's open question scoped it; T-0033's recorded limit on that point
  stands unchanged.
