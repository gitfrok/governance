# T-0073: The admin area view — a dated report, and a door instead of a trail

- **Status:** Done (2026-08-19) — webfrontend@1d1d815; SPEC-0058 AC12–AC19 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0058 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0058-admin-area.md (AC12–AC19)
- **ADRs:** 0077, 0069, 0070, 0033 (the grant flow this links into)
- **Owner:** unassigned

## Goal

The browser half of SPEC-0058. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0058 AC12–AC19 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **The age is the most prominent field.** A fleet panel that renders status without saying when the
  plane last said so misrepresents an outbound-only architecture as a live console.
- **No members panel and no `Last active`.** The first has no port behind it; the second is presence
  telemetry this product has declined to collect. Both are held by the copy enumeration.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0058 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
