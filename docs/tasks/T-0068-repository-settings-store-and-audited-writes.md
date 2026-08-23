# T-0068: Repository settings on the registry record, and an audited write path

- **Status:** Done (2026-08-19) — backend@6fe014c; SPEC-0057 AC1–AC9 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0057 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0057-repository-settings.md (AC1–AC9)
- **ADRs:** 0076, 0071, 0007, 0070, 0022, 0006
- **Owner:** unassigned

## Goal

One repository's share of SPEC-0057, split along the ADR-0027 boundary. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0057 AC1–AC9 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **Archival is a label, not an enforcement.** AC7 is the executable form of ADR-0076 decision 1: an
  archived repository still lists, still reads, and is still writable. A read-only condition needs a
  cause from a two-member vocabulary and `readonly-cause` is a phase-wide pin.
- **The audit port is declared here, filled in `cmd/`.** Repository is a leaf at fan-out zero and
  stays one; importing the Audit context would invert the module graph for one call.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0057 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
