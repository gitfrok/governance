# T-0036: Durable agent stores — enrolment-token store and data-plane registry

- **Status:** Todo
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
- [ ] AC1: token spend and revocation survive a control-plane kill-and-restart — a token spent before
      the restart is refused when replayed after it, including retry-after-partial-enrolment
      (SPEC-0038 AC1); a revocation issued before the restart still refuses the next connection.
- [ ] AC2: the registry staleness machine — NEVER_CONNECTED, CONNECTED, STALE, REVOKED — recomputes
      from durable liveness records after a restart, exactly as distinguishable as before it;
      staleness never derives from process uptime and a stale data plane is never rendered healthy
      (SPEC-0038 AC8).
- [ ] AC5 (agent tables): additive, rollback-tested up/down migrations under the agent module's own
      `internal/adapters/postgres/migrations`; RLS tenant scoping (ADR-0003); enrolment tokens persist
      as one-way hashes only — never raw (SPEC-0038 AC2, now the store as well as the logs). The one
      named exemption is the token table's hash-keyed lookup (`TokenByHash`, `ClaimToken`), which runs
      before any tenant is known: implement it as a single-purpose grant or `SECURITY DEFINER` lookup
      matching the unique hash column, returning at most one row, with the tenant bound **from that
      row**; every other path stays scoped, and a test enumerates the exempt set so a new one fails
      the suite.
- [ ] AC6: a failed certificate issuance does not silently consume the token. Decide and prove one
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
