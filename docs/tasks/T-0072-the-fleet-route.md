# T-0072: The fleet route, and an unavailable door that is not an empty fleet

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** bff
- **Spec:** ../specs/SPEC-0058-admin-area.md (AC9–AC11)
- **ADRs:** 0077, 0070, 0022, 0006
- **Owner:** unassigned

## Goal

The BFF half of SPEC-0058. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0058 AC9–AC11 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **An unconfigured door is unavailable, not empty.** Reporting no data planes for a tenant that has
  them is the failure mode this route exists to avoid — the same distinction the repository list draws
  between "you may see none" and "there are none".

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
