# T-0078: The Code Review context keeps what it was told

- **Status:** Not started
- **Phase / Epic:** 4 / EP-29 (durability debt, after Phase 4)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0061-code-review-durable-store.md (AC1–AC16)
- **ADRs:** 0080, 0071, 0062, 0003, 0025
- **Owner:** unassigned

## Goal

SPEC-0061 in one task, in one repository. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0061 AC1–AC16 — as written in the spec.

## Tests to write first

- The scoping refusals (AC5, AC6) and the call-site pairing (AC7) before the adapter, because they
  are the properties an adapter is easiest to write without.

## Notes / open questions

- **The order that makes this reviewable:** migration and its text test, then the adapter one port
  method at a time against a real Postgres, then the wiring. Eleven methods and five tables in one
  task is the diff shape reviewers trust least, so each step should stand on its own.
- **The version guard changes behaviour**, not just storage: a zero-row update is a conflict. The
  service already maps that error, so nothing on the wire moves — but it is the one place where this
  task could break a caller, and AC10 is the test that says it did not.
- **Do not touch the port.** ADR-0080 refused widening it, and the whole scoping design depends on
  that refusal holding.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
