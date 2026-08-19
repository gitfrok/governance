# T-0075: The link and unlink routes

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** bff
- **Spec:** ../specs/SPEC-0059-external-issue-references.md (AC11–AC13)
- **ADRs:** 0074, 0070, 0022, 0006
- **Owner:** unassigned

## Goal

The BFF half of SPEC-0059. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0059 AC11–AC13 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **A bad URL is the one distinguished outcome.** It is about the field the caller just sent. Everything
  else — including whether the merge request exists — is the same coarse refusal.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
