# T-0074: The external issue reference, its action, and the gate that keeps tracker content out

- **Status:** Done (2026-08-19) — governance@04c0455, backend@15c5cc5; SPEC-0059 AC1–AC10 proven there.
  **Record advanced 2026-08-23:** the work landed on 2026-08-19 and this line was never
  moved. SPEC-0059 carried the evidence and the epic table recorded the close; only this
  file said otherwise.
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** governance (contracts + policies) → backend
- **Spec:** ../specs/SPEC-0059-external-issue-references.md (AC1–AC10)
- **ADRs:** 0074, 0029, 0022, 0006, 0027
- **Owner:** unassigned

## Goal

The wire, the policy and the backend half of SPEC-0059. Two commits, one per repository
(invariant 25): contracts and the authz addition in `governance/`, then the aggregate and the service
in `backend/`.

## Acceptance criteria (test-first)

- [x] SPEC-0059 AC1–AC10 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **Nothing reads the tracker.** No client, no fetch, no webhook. AC7 asserts the absence of the path,
  not just the absence of a call — a port that could acquire one is the thing to keep out.
- **The URL is a link a person clicks from inside the product.** `https` only, refused in the domain,
  and the frontend refuses again (AC17). Two refusals, because this one is worth refusing twice.
- **Merge requests are not durable.** The reference is exactly as durable as the merge request, which
  is a recorded gap needing its own ADR (SPEC-0059 open question 1), not something to fix here.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

**Why this record was wrong.** It read `Not started` until 2026-08-23 while the code was on
`main` and SPEC-0059 was Implemented. Anyone picking this up from the task file alone would
have redone finished work. The lesson is the one the tree keeps relearning: a state that advances
in one place and not the other is worse than no record, because it reads as authoritative.
