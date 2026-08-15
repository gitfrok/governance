# T-0036: Durable agent stores — enrolment-token store and data-plane registry

- **Status:** Done (2026-08-15) — backend@c9e58c5; SPEC-0042 AC1, AC2, AC5 (agent half) and AC6
  proven against a real-Postgres harness with zero skips; recorded limits below
- **Phase / Epic:** 3.1 / EP-19 (durable control-plane stores)
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0042-durable-agent-residency-stores.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0062, 0003, 0023, 0025, 0055, 0060 (one token never mints two identities — AC6's bound), 0066 (issuance becomes a remote call — AC6's reason)
- **Owner:** unassigned

## Goal

Make PR-20's enrolment state a property of the platform rather than of a process: Postgres adapters
for the enrolment-token store and the data-plane registry behind the ports T-0030 left in memory, so
a spent token stays spent, a revocation still refuses, and the registry's staleness machine survives
a control-plane kill-and-restart (ADR-0062).

## Acceptance criteria (test-first)

SPEC-0042 AC1, AC2, AC6, and the agent-module half of AC5 (AC3, AC4 and the residency tables are
T-0037's):
- [x] AC1: token spend and revocation survive a control-plane kill-and-restart — a token spent before
      the restart is refused when replayed after it, including retry-after-partial-enrolment
      (SPEC-0038 AC1); a revocation issued before the restart still refuses the next connection.
- [x] AC2: the registry staleness machine — NEVER_CONNECTED, CONNECTED, STALE, REVOKED — recomputes
      from durable liveness records after a restart, exactly as distinguishable as before it;
      staleness never derives from process uptime and a stale data plane is never rendered healthy
      (SPEC-0038 AC8).
- [x] AC5 (agent tables): additive, rollback-tested up/down migrations under the agent module's own
      `internal/adapters/postgres/migrations`; RLS tenant scoping (ADR-0003); enrolment tokens persist
      as one-way hashes only — never raw (SPEC-0038 AC2, now the store as well as the logs). The one
      named exemption is the token table's hash-keyed lookup (`TokenByHash`, `ClaimToken`), which runs
      before any tenant is known: implement it as a single-purpose grant or `SECURITY DEFINER` lookup
      matching the unique hash column, returning at most one row, with the tenant bound **from that
      row**; every other path stays scoped, and a test enumerates the exempt set so a new one fails
      the suite.
- [x] AC6: a failed certificate issuance does not silently consume the token. Decide and prove one
      behaviour — release the claim on issuance failure, or keep the spend with a named operator
      recovery — with ADR-0060's rule intact either way: one token never mints a second data-plane
      identity, so any retry is bound to the `data_plane_id` the claim recorded. The chosen behaviour
      goes in the runbook beside SPEC-0044 AC4's custody procedures (coordinate with T-0040; the
      runbook edit may ride either task's super-repo commit, not both).

## Tests to write first

Per SPEC-0042 § Test plan:
- integration: every AC against a real Postgres harness — the in-memory fakes stay for the fast
  suites; durability is proven against the real adapter, not the double.
- chaos-restart: spend → kill −9 → restart → replay (AC1); connect → kill → restart → read registry
  states (AC2).
- migration up/down per module, plus an RLS assertion query per new table and the exempt-path
  enumeration test (AC5).
- signer-failure test: a custody fake that refuses to sign, driven through the enrolment path —
  asserts AC6's chosen behaviour and that no second identity is reachable for that token.
- `go test -race` across the new adapters for concurrent spend paths.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — RLS, tenant scoping, audit.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race` — including the real-Postgres harness above.

## Notes / open questions

AC6 exists because this task and T-0040 together change an assumption neither changes alone: spend
becomes durable here, issuance becomes a remote quorum call there, and the window between
`ClaimToken` and `Issue` (today `backend/modules/agent/internal/app/service.go:294-320`, commented
*"the token stays spent"*) turns an availability event into a dead customer credential. Decide it in
this task rather than discovering it in EP-21.

The in-memory fakes stay behind the same ports as test doubles, not as a deployment posture
(ADR-0062 decision 1). Store growth is unmetered here and stays on ADR-0055's follow-up — durability
is not held hostage to the meter. Sequencing: EP-19's first task; T-0037 repeats this task's
adapter/migration pattern for the residency store and the pack assembly that reads it.

## Exit record (2026-08-15)

Implemented test-first and merged to backend main at **c9e58c5** (commits **4406a97** schema +
SQL-boundary tests, **584d95b** harness repair, **23b89b3** unwired adapters, **a0def18** AC6
release-the-claim, **c9e58c5** composition-root swap + app-level chaos proofs). Every proof below
ran against the **real-Postgres harness** — `kubectl port-forward svc/postgres 15432:5432` on the
minikube profile `gitfrok` — with **zero skips** in the agent durability tests.

**SPEC-0042 AC1, AC2, AC5 (agent half), AC6 — one line of proof each:**

- **AC1** — token spend and revocation survive a control-plane kill-and-restart, including
  concurrent claims: `TestAC1_SpentTokenStaysSpentAcrossKillRestart`,
  `TestAC1_RevocationBeforeRestartStillRefuses`, `TestAC1_ConcurrentClaimsExactlyOneSpends`,
  plus the app-level chaos proofs over the real enrolment path.
- **AC2** — the staleness machine recomputes from durable liveness after a restart, never from
  process uptime: `TestAC2_StalenessRecomputedFromDurableLivenessAfterRestart` plus the app-level
  proof.
- **AC5 (agent tables)** — additive, reversible migrations with RLS forced and the exempt paths
  enumerated: `TestAC5_UpAndDownMigrationsAreReversible`,
  `TestAC5_RLSEnabledForcedWithTenantIsolationPolicy`, `TestAC5_RLSIsolatesTenantsAtTheSQLLayer`,
  `TestAC5_ExemptPathEnumeration`, `TestExemptPathsAreNarrowAndEnumerated`,
  `TestEnrolmentMigrationStoresHashesOnly` (tokens persist as one-way hashes only).
- **AC6** — **decided: release the claim on issuance failure** (user-approved 2026-08-15). The
  claim's recorded `data_plane_id` is kept when the claim is released, so any retry re-binds the
  SAME identity — one token never mints a second data plane (ADR-0060). Proven by
  `TestStore_ReleaseClaimKeepsRecordedDataPlane`,
  `TestEnrolIssuanceFailureReleasesClaimKeepingIdentity`,
  `TestEnrolReleasedClaimStillHonoursRevocation` (a released claim still refuses a revoked token).

**Deviation (recorded, not silent):** commit **584d95b** repaired two **pre-existing** audit and
policy test-harness bugs that the durability gates surfaced — the gates could not go green while
they failed, and the fix touches test harness only, not behaviour. It rides this task's commit stack
rather than its own task because nothing else could proceed past it.

**Recorded limits (write the limit down):**

- **CI skips these proofs without `TEST_DATABASE_URL`.** The real-Postgres harness is a local
  run; the CI lane runs the in-memory fakes and skips the durability suite when no database is
  provided — the same recorded shape as Phase 3's integration suites (HANDOFF known gap 5).
  The proofs above are real but rest on this local run.
- **The AC6 runbook edit is deferred to T-0040's super-repo commit.** This task permits the
  runbook edit to ride either task's super-repo commit, not both; T-0040 already owns the custody
  procedures beside SPEC-0044 AC4, so the single edit lands there. Until then the chosen behaviour
  (release the claim, keep the recorded identity, retry re-binds) is recorded here and in the
  migration's own header comment.
- AC3, AC4 and the residency tables remain T-0037's, as the task scoped them.
