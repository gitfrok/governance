# T-0076: External issues on the merge request, and a link a reader can see the end of

- **Status:** Done (2026-08-19) — webfrontend@c525b55; SPEC-0059 AC14–AC19 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0059 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0059-external-issue-references.md (AC14–AC19)
- **ADRs:** 0074, 0069, 0070
- **Owner:** unassigned

## Goal

The browser half of SPEC-0059, on the existing merge request page. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0059 AC14–AC19 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **The host is shown, not hidden.** A reference is a link out of the product, and a reader should be
  able to see where it goes before clicking.
- **Merging closes nothing.** That is the first assumption a reader makes, so the page says it rather
  than letting the absence be discovered.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0059 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
