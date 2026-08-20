# T-0078: The Code Review context keeps what it was told

- **Status:** Stopped 2026-08-21 — Proposed ADR-0084 (the Save-shape conflict) awaits a decision
- **Phase / Epic:** 4 / EP-29 (durability debt, after Phase 4)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0061-code-review-durable-store.md (AC1–AC16)
- **ADRs:** 0080, 0071, 0062, 0003, 0025, 0084 (Proposed)
- **Owner:** unassigned

## Goal

SPEC-0061 in one task, in one repository. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0061 AC1–AC16 — as written in the spec.

## Tests to write first

- The scoping refusals (AC5, AC6) and the call-site pairing (AC7) before the adapter, because they
  are the properties an adapter is easiest to write without.

## Notes / open questions

- **Stopped at RED 2026-08-21.** The adversarial review before commit found that AC9's guard and
  the service's version-preserving projection write (the ref-update event path) cannot coexist in
  one `Save` — Proposed ADR-0084 records the conflict and proposes the split. Nothing commits
  until that decision lands; the spec is then amended and RED resumes.
- **What the stopped run already proved** (backend work-in-progress, uncommitted): the migration
  and its text tests, the scoping refusals, the call-site pairing test, and all seventeen
  real-Postgres proofs ran green with `-race` and **zero skips** against the dev cluster's
  Postgres (2026-08-21); the full backend suite passed at the same pins. The review's findings
  were the version guard's event-path shape, the missing `ErrVersionConflict` mapping, `Merge`'s
  move-before-save ordering, and the `CreateOrGet` race — none of them in the proofs above.

- **The order that makes this reviewable:** migration and its text test, then the adapter one port
  method at a time against a real Postgres, then the wiring. Eleven methods and five tables in one
  task is the diff shape reviewers trust least, so each step should stand on its own.
- **The version guard changes behaviour**, not just storage: a zero-row update is a conflict.
  The 2026-08-21 review corrected this note's earlier claim — the service maps every `Save`
  error to `ErrDenied` today, and its ref-update path `Save`s without bumping the version on
  purpose. Both findings live in ADR-0084; AC10 is the test that says the wire did not move.
- **Do not touch the port.** ADR-0080 refused widening it, and the whole scoping design depends on
  that refusal holding.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
