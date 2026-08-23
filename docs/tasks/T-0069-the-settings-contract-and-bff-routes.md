# T-0069: The settings contract, the gate that keeps policy off it, and the BFF routes

- **Status:** Done (2026-08-19) — governance@9122a0d, bff@f7d6067; SPEC-0057 AC10–AC14 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0057 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** governance (contracts) → bff
- **Spec:** ../specs/SPEC-0057-repository-settings.md (AC10–AC14)
- **ADRs:** 0076, 0070, 0022, 0006, 0027
- **Owner:** unassigned

## Goal

The wire and the BFF half of SPEC-0057. Two commits, one per repository (invariant 25): the contract
in `governance/`, then the routes in `bff/`.

## Acceptance criteria (test-first)

- [x] SPEC-0057 AC10–AC14 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **The descriptor gate is the deliverable, not the paperwork.** AC11 and AC12 are the fourth
  deferral gate in this phase, after job logs (check 13), policy authoring (check 14) and release
  artifacts (check 15). A "require approvals" checkbox is the thing PR-10 forbids and the thing a
  settings page attracts; a compiled-descriptor assertion is the only form of refusal that survives.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0057 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
