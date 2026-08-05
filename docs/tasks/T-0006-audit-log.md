# T-0006: Append-only audit log

- **Status:** In progress — contract landed; writer/verifier next
- **Phase / Epic:** 0 / EP-2
- **Repo(s):** governance (`contracts/events` — `AuditEvent`, additive) → backend
- **Spec:** docs/specs/SPEC-0003-audit-log.md
- **ADRs:** 0007, 0022
- **Owner:** unassigned

## Goal
Tamper-evident, append-only audit sink with no delete path.

## Acceptance criteria (test-first)
- [ ] AC1: Writes are append-only; there is no update/delete API.
- [ ] AC2: Entries are hash-chained; a verifier detects tampering.
- [ ] AC3: A sample sensitive action emits an audit event.
- [ ] AC4: Audit is a separate store from observability/telemetry.
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
