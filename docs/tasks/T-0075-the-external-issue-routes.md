# T-0075: The link and unlink routes

- **Status:** Done (2026-08-19) — bff@a196d03; SPEC-0059 AC11–AC13 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0059 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** bff
- **Spec:** ../specs/SPEC-0059-external-issue-references.md (AC11–AC13)
- **ADRs:** 0074, 0070, 0022, 0006
- **Owner:** unassigned

## Goal

The BFF half of SPEC-0059. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0059 AC11–AC13 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **A bad URL is the one distinguished outcome.** It is about the field the caller just sent. Everything
  else — including whether the merge request exists — is the same coarse refusal.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0059 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
