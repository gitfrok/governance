# SPEC-0042: Durable agent and residency stores

- **Status:** Implemented (2026-08-15) — every acceptance criterion is proven by its task(s); approved (2026-08-15; **amended 2026-08-15 after the Phase 3.1 plan review** — AC5 names the enrolment-token lookup exemption it previously forbade by accident, and AC6 fixes what a failed signature does to a spent token)
- **Owner:** platform
- **Context(s):** Control plane — agent (tokens, registry) · residency (declarations) · audit (pack assembly reads) — ADR-0022
- **ADRs:** 0062 (decides durability), 0003 (RLS tenant scoping), 0023 (PostgreSQL 18), 0025 (module-owned migrations), 0055 (growth metering stays a follow-up), 0060 (one token never mints two identities), 0066 (issuance becomes a remote call — AC6's reason)
- **Task(s):** T-0036 (agent tables: AC1, AC2, AC6, AC5 agent half), T-0037 (residency tables: AC3, AC4, AC5 residency half)

## Problem / context

PR-20 and PR-22 both rest on control-plane state that Phase 3 kept in memory: the enrolment-token
store and data-plane registry (T-0030) and the residency declaration store (T-0033). Both exit
records say so plainly — the stores do not survive a control-plane restart — and the phase plan
carries the item. What a restart loses is not convenience: a spent token reads as unspent, every
staleness distinction collapses, and the declarations the evidence pack cites vanish while the audit
trail that recorded them stays.

ADR-0062 (Accepted) decides the fix: Postgres adapters behind the existing module ports, swapped at
the composition root, additive module-owned migrations, RLS on every new table, effective-dated
declarations, and pack assembly from durable projections only. This spec turns that decision into
testable behaviour for Phase 3.1 epic **EP-19** (PR-20/PR-22).

## In scope

- Postgres adapters for the enrolment-token store, the data-plane registry and the residency
  declaration store, behind the ports that already exist.
- Additive, module-owned, rollback-tested migrations for the new tables.
- RLS tenant scoping on every new table; token hashes at rest.
- Staleness computed from durable liveness records; declarations effective-dated.
- Evidence-pack residency assembly reading durable projections only.

## Out of scope

- Any new store engine, snapshot-file persistence or SQLite sidecar (rejected by ADR-0062).
- Metering the growth of the new tables — that joins ADR-0055's open follow-up rather than spawning
  a new one; durability is not held hostage to the meter.
- Migrating existing tenant data across a residency change — undesigned and out of scope (SPEC-0040).
- Any change to the agent channel or to ADR-0060 enrolment semantics.
- Inbound paths of any kind (Phase 3.1 non-goal).

## Contracts touched

None. Ports and adapters are internal to the backend; no `contracts/` surface changes.

## Data owned

The agent module owns the token and registry tables; the residency module owns the declaration
tables — each under its own `internal/adapters/postgres/migrations`, no shared grab-bag schema
(ADR-0062 decision 2). Audit continues to own the pack and reads the residency store through its
existing module boundary.

## Acceptance criteria (each becomes a test)

- [ ] AC1: Enrolment-token spend and revocation state survives a control-plane kill-and-restart. A
  token spent before the restart is refused when replayed after it, including the retry-after-partial-
  enrolment case (SPEC-0038 AC1); a revocation issued before the restart still refuses the next
  connection. Single-use is a property of the platform, not of a process. (What counts as *spent*
  when the issuance itself failed is AC6's to decide; this AC governs a token spent on an enrolment
  that completed.)
- [ ] AC2: The registry staleness machine — NEVER_CONNECTED, CONNECTED, STALE, REVOKED — is
  recomputed from durable state after a restart, exactly as distinguishable as before it. Staleness
  derives from recorded liveness (last-seen and contact history), never from process uptime, and a
  stale data plane is never rendered as healthy (SPEC-0038 AC8).
- [ ] AC3: Residency declarations are durable and effective-dated. A declare or replace appends a new
  row and retains history; the declaration in force at any point in a range is answerable from the
  store. The evidence pack's residency section (SPEC-0040 AC4–AC6) is reproducible from the store
  after a restart: a pack assembled after cites what one assembled before would.
- [ ] AC4: Evidence-pack assembly structurally cannot reach in-process stores. An architecture
  fitness test asserts no assembly path reads process memory — the property is enforced by
  construction, not by review.
- [ ] AC5: Migrations are additive and rollback-tested (up/down verified); every new table carries
  RLS tenant scoping (ADR-0003); and enrolment tokens persist as one-way hashes only — never
  persisted, logged or recoverable in raw form (SPEC-0038 AC2, now applied to the store as well as
  the logs).
  **One exemption exists and is named here rather than invented in an adapter:** enrolment resolves
  the tenant *from* the token, so the two hash-keyed lookups on the token table
  (`TokenByHash`, `ClaimToken`) run before any tenant is known and cannot be tenant-scoped. They run
  under a narrow, single-purpose exemption — a dedicated grant or `SECURITY DEFINER` lookup — bounded
  by three tested properties: the lookup matches on the unique token-hash column only and can return
  at most one row; the tenant for everything after it is bound **from that row**, never from the
  caller; and every other query path on the token table, and every path on every other new table, is
  tenant-scoped with no exemption. A test enumerates the exempt paths and fails when a new one
  appears.
- [ ] AC6: A failed certificate issuance does not silently consume the customer's token. Enrolment
  today spends first and keeps the token spent when the signer fails — safe while the signer was
  in-process and a restart cleared the spend, and no longer safe once spend is durable (AC1) and
  issuance is a remote call to a quorum-serialized custody service (ADR-0066), where an availability
  event becomes a permanently dead credential. The implementation may either release the claim when
  issuance fails, or keep the spend and expose the operator recovery — but whichever it is, is proven
  by a test with the signer failing, and **ADR-0060's rule holds in both cases: one token never mints
  a second data-plane identity**, so any retry path is bound to the same `data_plane_id` the claim
  recorded. The chosen behaviour is named in the runbook alongside SPEC-0044 AC4's custody
  procedures.

## Test plan

- Integration tests for every AC against a real Postgres harness — the in-memory fakes stay for the
  fast suites, but durability is proven against the real adapter, not the double.
- Chaos-restart suite: spend → kill −9 → restart → replay (AC1); connect → kill → restart → read
  registry states (AC2); declare → kill → restart → assemble pack (AC3).
- Architecture fitness test for AC4 (pack assembly path).
- `go test -race` across the new adapters for concurrent spend/replace paths.
- Migration up/down tests per module (AC5), plus an RLS assertion query per new table and an
  enumeration test over the token table's exempt paths — a new un-scoped path fails the suite (AC5).
- Signer-failure test: a fake custody provider that refuses to sign, exercised through the enrolment
  path, asserting the chosen AC6 behaviour and that no second identity is reachable for that token.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 Tenant isolation | RLS on every new table; the single hash-lookup exemption is named, bounded to one row, and enumerated by test — the tenant is bound from the stored row, never from the caller (AC5) |
| G5 Auditability | spend, revocation and declaration state survive restarts, so the audited act and the enforced state cannot diverge (AC1–AC3) |
| G6 Compliance frameworks | the pack's residency section is reproducible from durable state, not from a process's memory (AC3, AC4) |
| G9 Least-privilege footprint | restart-safety removes an operator ritual (rebuilding state by hand) and a silent-failure mode |

## Non-functional

- Dev and test keep the in-memory fakes behind the same ports; they are test doubles, not a
  deployment posture (ADR-0062 decision 1).
- Store growth is unmetered by this spec and stays on ADR-0055's follow-up.
- The stores inherit Postgres backup and restore; no bespoke recovery path is added.

## Open questions / assumptions

- Assumed: one control-plane app binary writes these tables (ADR-0025), so no cross-process cache
  invalidation is needed beyond the transactional boundary.
- Assumed: the audit trail remains the reconstructable fallback for a declaration; the durable store
  removes the need to reconstruct, it does not change what the audit record is.
