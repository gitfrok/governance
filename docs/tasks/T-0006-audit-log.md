# T-0006: Append-only audit log

- **Status:** Done (2026-08-06) — AC1–AC4; one limit recorded below
- **Phase / Epic:** 0 / EP-2
- **Repo(s):** governance (`contracts/events` — `AuditEvent`, additive) → backend
- **Spec:** docs/specs/SPEC-0003-audit-log.md
- **ADRs:** 0007, 0022
- **Owner:** unassigned

## Goal
Tamper-evident, append-only audit sink with no delete path.

## Acceptance criteria (test-first)
- [x] AC1: Writes are append-only; there is no update/delete API.
- [x] AC2: Entries are hash-chained; a verifier detects tampering.
- [x] AC3: A sample sensitive action emits an audit event.
- [x] AC4: Audit is a separate store from observability/telemetry.
      **This AC is in SPEC-0003 and was missing from this list** — the spec is authoritative
      (ADR-0001), so it is added rather than quietly dropped.

## Tests to write first
- unit: hash-chain writer + verifier (including a tamper case that must fail).
- integration: persistence with no mutation path exposed.
NOTE: write SPEC first.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.

## The contract (landed first, per ADR-0027)

`contracts/events/audit/v1/events.proto` — one generic `AuditEvent` with a typed `action`, rather
than a message per auditable action. SPEC-0003 asks for "an `AuditEvent` shape", and the alternative
scales badly: every new sensitive action would become a contracts change, and evidence export
(PR-17/PR-18) would have to know every message type that ever existed.

Two deliberate absences:

- **No sequence number and no hashes.** Entries are hash-chained by the audit *store* (ADR-0007); the
  chain is a property of the log, not the message. An emitter cannot know its position in a chain it
  has not been appended to, and a producer able to state its own hash could also lie about it.
- **No payloads.** Identifiers, outcomes and small machine-readable detail only — an audit record of
  an attempted leak must not become the vehicle that copies the data somewhere less protected (G1).

`action` is a string, not an enum: an enum makes every new auditable action a contracts change *and*
a coordinated deploy, and ADR-0034's gate would rightly reject renaming a value later. A dotted
vocabulary is additive by construction.

### T-0004's provisional routing key is resolved — **renamed**

T-0004 emitted `gitsaas.events.audit.v1.TenantIsolationViolation`, flagged there as provisional
because no contract existed. It is now `gitsaas.events.audit.v1.AuditEvent` with
`action = "tenant.isolation.violation"` and `outcome = OUTCOME_DENIED`. Renaming was free precisely
because nothing subscribed yet — the reason T-0004 recorded it as a decision to make early rather
than a detail to discover late.

## Implementation record

| Repo | Merged | What |
|---|---|---|
| governance | `fdc5814` (#28) | `contracts/events/audit/v1` — one generic `AuditEvent` with a typed `action` |
| backend | `be0d108` (#8) | hash chain, append-only Postgres store, `modules/audit`, T-0004 event renamed onto the contract |

### How each AC is proven

- **AC1** — enforced by the *database*, not by Go. The application role holds `INSERT` and `SELECT`
  and nothing else; triggers reject mutation even for the table owner. So "there is no update path"
  is true for a `psql` session holding the application's credentials, not only for callers who go
  through the module. Asserted by attempting UPDATE, DELETE and TRUNCATE as that role.
- **AC2** — SHA-256 over a canonical, **length-prefixed** encoding, each hash binding its
  predecessor's. Four tamper modes are caught and reported *distinctly* — content altered, re-hashed
  in isolation, record removed, records reordered — because a mutation and a deletion are different
  incidents and an investigator should not have to infer which happened.
- **AC3** — a write refused by RLS emits `AuditEvent` with `action="tenant.isolation.violation"`.
- **AC4** — a dedicated `audit` schema, asserted against the catalog rather than the migration text,
  so moving the table without moving the guarantee fails.

### Two encoding details that look fussy and are not

**Length prefixes**, because a delimiter-joined form lets an attacker who controls two adjacent
fields swap their contents undetected. **Sorted map keys**, because Go randomises map iteration and an
unstable hash would fail verification at random — an alarm that cries wolf is how verifiers get
switched off.

### The limit: head truncation is not detectable

Deleting the *newest* records leaves a chain that is internally perfect. Detecting it needs an anchor
outside the database — an external witness, periodic notarisation, or WORM storage. ADR-0007 does not
decide that and this task does not add it. There is a passing test that names the gap rather than a
comment that hopes someone reads it.

### Three bugs found by running, not reading

1. **`SELECT ... FOR UPDATE` requires the UPDATE privilege**, which append-only revokes — an
   append-only table cannot lock its own rows. Replaced with a per-tenant advisory lock, which is
   also stronger: locking the head row would not stop two transactions that both read it before
   either inserted.
2. **The sequence was global while chains are per tenant.** Reads are RLS-scoped, so a verifier saw
   7, 19, 24 and reported a deletion that never happened — *invisible while one tenant writes alone*,
   which is exactly how it reaches production. Now a per-tenant `tenant_seq`.
3. **Tamper tests disabled triggers with `defer`**, so a killed run left the guard off and the next
   run's AC1 assertion silently stopped holding.

### Follow-ups (not blocking)

- **CI does not run AC1/AC2/AC4** — like T-0004's, they skip without `TEST_DATABASE_URL`. Two tasks
  now rest on integration tests that only run locally; a Postgres service container in backend CI is
  worth more than the next feature.
- **Nothing applies the migrations.** ~~`0001_audit_log.sql` was applied by hand to the dev cluster.
  T-0004 recorded the same gap; it now affects two schemas.~~ **Closed (recorded 2026-08-16).**
  `scripts/dev-provision.sh` applies every backend migration — this schema among them — idempotently
  as its first step; `make dev-provision` is the documented path. T-0004's twin of this bullet is
  corrected the same way.
- **`AuditEvent` has no parity test** yet — `modules/repository/api` has one binding its events to
  `contracts/events`, and the audit event should get the same treatment.
