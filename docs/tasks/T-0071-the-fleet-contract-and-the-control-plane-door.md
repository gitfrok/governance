# T-0071: The fleet contract, the door that serves it, and the gates that keep the trail out

- **Status:** Done (2026-08-19) — governance@0d1b79c, backend@688ed6e; SPEC-0058 AC1–AC8 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0058 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** governance (contracts + policies) → backend
- **Spec:** ../specs/SPEC-0058-admin-area.md (AC1–AC8)
- **ADRs:** 0077, 0060, 0007, 0006, 0022, 0027
- **Owner:** unassigned

## Goal

The wire and the backend half of SPEC-0058. Two commits, one per repository (invariant 25): the
contract and the rego gate in `governance/`, then the adapter and the door in `backend/`.

## Acceptance criteria (test-first)

- [x] SPEC-0058 AC1–AC8 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **The backend port already exists.** `Fleet` returns each data plane with its derived status and the
  instant it was last seen, and its comment already says stale reads stale. What is missing is an RPC,
  which is why this task is mostly contract and adapter.
- **Two gates, in two places.** The descriptor check keeps an audit read off `agent/v1` (decision 1);
  the rego test pins `role_actions` to owner, member and reader (decision 2). The second is the more
  important one — an `admin` role is what this ADR exists to prevent.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0058 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
