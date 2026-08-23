# T-0077: One type scale, one page shell, and the gate that keeps geometry in the token layer

- **Status:** Done (2026-08-19) — webfrontend@45ffd61 (the type scale, the shell and the gate)
  then webfrontend@5628286, the follow-up fix for the defect the shell adoption introduced —
  page chrome belonging outside the content column. SPEC-0060 AC1–AC10 proven across both;
  the spec's Status line cites the feature commit and the task index cites the fix.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0060 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-28 (the design layer, after Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0060-dimensional-tokens-and-page-shell.md (AC1–AC10)
- **ADRs:** 0079, 0069, 0015, 0047
- **Owner:** unassigned

## Goal

SPEC-0060 in one task, in one repository. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0060 AC1–AC10 — as written in the spec.

## Tests to write first

- The gate and its fixture (AC3, AC4, AC5) before converting anything: a conversion done before the
  check exists is a conversion nobody can prove finished.

## Notes / open questions

- **32 files at once is the diff shape reviewers trust least.** The order that makes it reviewable:
  tokens first, then the gate with its fixture, then the shell, then the files — so each commit-sized
  step is either a definition, a check, or a mechanical substitution.
- **Three visible changes only:** 11→12, 15→16, 24→22. Anything else moving on screen is a defect,
  and the captures are where it shows.
- **The waiver count is a deliverable, not a detail.** ADR-0079's follow-up is decided from it.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0060 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
