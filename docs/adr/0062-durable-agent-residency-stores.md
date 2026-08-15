# ADR-0062: The agent and residency stores are durable Postgres behind their existing ports

- **Status:** Proposed (2026-08-15)
- **Deciders:** product/architecture (proposed by AGDD Phase 3.1 planning)
- **Supersedes / superseded by:** —
- **Related:** ADR-0003 (shared DB + RLS), ADR-0023 (stack: PostgreSQL 18), ADR-0055 (unbounded
  growth is a metering follow-up, not a reason not to persist), SPEC-0038, SPEC-0040, T-0030,
  T-0033

## Context

Phase 3 shipped three control-plane stores as in-memory adapters behind their module ports: the
enrolment-token store and the data-plane registry in the agent module (T-0030), and the residency
declaration store in the residency module (T-0033). Both exit records name the limit plainly — the
stores do not survive a control-plane restart — and the phase plan carries it as part of its
carried set.

What a restart actually loses is worse than convenience. Token **spend state**: a token spent
before the restart reads as unspent after it, so the single-use property SPEC-0038 AC1 asserts is
true of a process, not of a platform. **Registry liveness**: last-seen and every staleness
distinction (SPEC-0038 AC8) collapse, and connected data planes render as never-connected. **The
residency declaration itself**: the audit trail remains durable, so the declaration is
reconstructable from the record, but the live store is gone — and the evidence pack's residency
section (SPEC-0040 AC4–AC6) reads declarations in force and observed placements, which is exactly
the state that vanished.

The ports already exist; only the adapters are volatile.

## Decision

**Postgres adapters behind the existing module ports, swapped at the composition root. The domain
and application layers do not change, and no new store engine enters the platform.**

1. **Adapters, not redesign.** Each store gets a Postgres adapter behind the port it already
   defines, wired at the composition root exactly as the in-memory adapter is today. Dev and test
   may keep the in-memory fakes behind the same ports; they are test doubles, not a deployment
   posture.
2. **Module-owned additive migrations.** New tables migrate under the owning module's
   `internal/adapters/postgres/migrations`, the pattern identity, audit, policy and security
   already follow. Additive only — no in-place rewrites, no shared "platform" grab-bag schema.
3. **RLS tenant scoping on every new table** (ADR-0003). No un-tenant-scoped query path exists for
   the agent channel, and none is added for its stores.
4. **Token hashes at rest, preserved.** The Postgres adapter persists the same one-way hash the
   current adapter keeps; an enrolment token is never persisted, logged, or recoverable from the
   store (SPEC-0038 AC2's rule, now applied to durability rather than only to logs).
5. **Registry staleness is computed from durable liveness records.** Last-seen (and the contact
   history that feeds staleness) persist, so a control-plane restart leaves every AC8 state —
   connected, stale, revoked, never-connected — exactly as distinguishable as before it. Staleness
   is derived from recorded liveness, never from process uptime.
6. **Residency declarations are effective-dated.** A declare or replace appends a new
   effective-dated row; history is retained, never updated in place. SPEC-0040 AC6's "a change
   inside the range shows as a change with its effective time" becomes a property of the store,
   not of the code that happens to read it.
7. **Evidence-pack assembly reads durable projections only.** No assembly path remains that reads
   process memory; a pack assembled after a restart cites the same declarations and placements one
   assembled before it would.

**Rejected: in-memory plus snapshot files.** The cheap fix. But spend state and effective-dated
declarations are exactly the things a torn or lost snapshot corrupts — there is no transactional
crash consistency, and the failure mode is a spent token reading as unspent, which is the
integrity property, not a performance detail.

**Rejected: a SQLite sidecar.** Durable and embedded, but it puts a second database engine inside
the control plane for three tables, with its own backup, upgrade and concurrency story, no HA
path, and a divergence from the platform store (ADR-0023) that every operator and every restore
drill then inherits.

## Consequences

- Restart-safety becomes provable by test: spend a token, restart, replay the token — refused;
  connected before the restart, still connected (or stale on the clock, not on the process) after
  it.
- The migration discipline is additive by construction, and the stores inherit Postgres backup and
  restore rather than inventing their own.
- Store growth is unmetered, the same shape ADR-0055 recorded for the audit store. Metering the
  growth of these tables joins that follow-up rather than spawning a new one; durability is not
  held hostage to the meter.
- Dev and test keep the in-memory fakes, so the suites stay fast and hermetic behind the same
  ports the production adapter implements.
