# T-0078: The Code Review context keeps what it was told

- **Status:** In progress — RED resumed 2026-08-21 on the amended spec (ADR-0084 Accepted the same
  day)
- **Phase / Epic:** 4 / EP-29 (durability debt, after Phase 4)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0061-code-review-durable-store.md (AC1–AC18)
- **ADRs:** 0080, 0071, 0062, 0003, 0025, 0084 (Accepted — the write split)
- **Owner:** unassigned

## Goal

SPEC-0061 in one task, in one repository. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0061 AC1–AC18 — as written in the spec.

## Tests to write first

- The scoping refusals (AC5, AC6) and the call-site pairing (AC7) before the adapter, because they
  are the properties an adapter is easiest to write without.

## Notes / open questions

- **Stopped at RED 2026-08-21, resumed the same day.** The adversarial review before commit found
  that AC9's guard and the service's version-preserving projection write (the ref-update event
  path) cannot coexist in one `Save`; ADR-0084 decided the split and was accepted as written.
  SPEC-0061 is amended (AC9–AC12 carry the split; AC3 converges; AC7's test shape is restated)
  and RED resumes on the amended spec.
- **What the stopped run already proved** (backend work-in-progress, uncommitted): the migration
  and its text tests, the scoping refusals, the call-site pairing test, and all seventeen
  real-Postgres proofs ran green with `-race` and **zero skips** against the dev cluster's
  Postgres (2026-08-21); the full backend suite passed at the same pins. The review's findings
  were the version guard's event-path shape, the missing `ErrVersionConflict` mapping, `Merge`'s
  move-before-save ordering, and the `CreateOrGet` race — none of them in the proofs above, and
  each now has its criterion.

- **The order that makes this reviewable:** migration and its text test, then the adapter one port
  method at a time against a real Postgres, then the wiring. Eleven methods and five tables in one
  task is the diff shape reviewers trust least, so each step should stand on its own.
- **The version guard changes behaviour**, not just storage: a zero-row update is a conflict.
  The 2026-08-21 review corrected this note's earlier claim — the service maps every `Save`
  error to `ErrDenied` today, and its ref-update path `Save`s without bumping the version on
  purpose. Both findings live in ADR-0084; AC11 is the test that says the wire did not move.
- **The port stays as ADR-0080 left it, plus exactly the one method ADR-0084 decision 1 adds** —
  the version-preserving projection write. ADR-0080's refusal to widen it for tenancy stands, and
  the whole scoping design depends on that refusal holding; the new method carries its tenant
  exactly as every other event-path method does.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
