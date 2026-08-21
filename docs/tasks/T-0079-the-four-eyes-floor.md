# T-0079: The four-eyes floor

- **Status:** Done (2026-08-21) — governance@39a2f1e+594aa40, backend@bed1194; SPEC-0062 AC1–AC5
  proven; 189/189 rego tests
- **Phase / Epic:** EP-30 (the review loop, completed)
- **Repo(s):** governance, backend
- **Spec:** ../specs/SPEC-0062-four-eyes-floor.md (AC1–AC5)
- **ADRs:** 0085, 0006, 0029 §4
- **Owner:** unassigned

## Goal

Every merge needs two non-author approvals, platform-wide, decided in the bundle.

## Acceptance criteria (test-first)

- [x] SPEC-0062 AC1–AC5 — as written in the spec.

## Tests to write first

- The bundle's own tests: floor passes at exactly two on an unprotected target; one approval
  denies across required = 0/1/2; the pre-floor single-approval ALLOW fixture flips to the new
  expectation with a comment naming ADR-0085.
- backend: the author's review is excluded from `validApprovals` and recorded anyway.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony (authorization surface).

## Notes / open questions

- The floor is a second inequality beside `required_approvals`, never a rewrite of the rule — the
  security findings gate composes above it unchanged.
- Backend service tests run against a recording PDP, so the floor itself is asserted in
  `authz_test.rego`; the service test asserts only that the author's approval does not change the
  assembled fact.

## Exit record (2026-08-21)

`approval_floor := 2` in `gitsaas/authz/authz.rego`, asserted by three new bundle tests; the
pre-floor "1 of 1 allows" fixture updated to the floor with its comment naming this ADR —
**187/187 rego tests green**. backend excludes `mr.CreatorID` from `validApprovals` (the review
still records and audits); the recording-PDP suite is unchanged because the fact assembly is what
moved. Full ceremony: authorization surface, so no tier applies.
