# T-0069: The settings contract, the gate that keeps policy off it, and the BFF routes

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** governance (contracts) → bff
- **Spec:** ../specs/SPEC-0057-repository-settings.md (AC10–AC14)
- **ADRs:** 0076, 0070, 0022, 0006, 0027
- **Owner:** unassigned

## Goal

The wire and the BFF half of SPEC-0057. Two commits, one per repository (invariant 25): the contract
in `governance/`, then the routes in `bff/`.

## Acceptance criteria (test-first)

- [ ] SPEC-0057 AC10–AC14 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **The descriptor gate is the deliverable, not the paperwork.** AC11 and AC12 are the fourth
  deferral gate in this phase, after job logs (check 13), policy authoring (check 14) and release
  artifacts (check 15). A "require approvals" checkbox is the thing PR-10 forbids and the thing a
  settings page attracts; a compiled-descriptor assertion is the only form of refusal that survives.
