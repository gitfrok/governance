# T-0070: The settings view, and an absence that is not a permission

- **Status:** Done (2026-08-19) — webfrontend@dc8307e; SPEC-0057 AC15–AC20 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0057 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0057-repository-settings.md (AC15–AC20)
- **ADRs:** 0076, 0069, 0070, 0022
- **Owner:** unassigned

## Goal

The browser half of SPEC-0057. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0057 AC15–AC20 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **No disabled controls.** A disabled control tells a reader they lack a permission. Visibility and
  membership are absent because the capability does not exist — SPEC-0055 AC7's rule, and AC16 tests
  the copy for the softer phrasings that would imply otherwise.
- **An archived repository is still writable.** AC17 renders that, because a label a reader
  misinterprets as read-only is worse than no label.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0057 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
