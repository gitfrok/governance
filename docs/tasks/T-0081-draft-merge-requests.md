# T-0081: Draft merge requests

- **Status:** Done (2026-08-21) — governance@this-commit (contract), backend + bff +
  webfrontend@their pins; SPEC-0064 AC1–AC7 proven
- **Phase / Epic:** EP-30 (the review loop, completed)
- **Repo(s):** governance, backend, bff, webfrontend
- **Spec:** ../specs/SPEC-0064-draft-merge-requests.md (AC1–AC7)
- **ADRs:** 0087, 0019, 0080, 0084
- **Owner:** unassigned

## Goal

Open a merge request that stays quiet until someone marks it ready.

## Acceptance criteria (test-first)

- [ ] SPEC-0064 AC1–AC7 — as written in the spec.

## Tests to write first

- The additive-default proof (AC1): creating without the field yields OPEN byte-for-byte — the
  contract's existing callers must not notice the change.
- The quiet-machinery proof (AC4): a push onto a draft's refs lands no projection and no
  announcement, then does after readiness.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- Contract is governance-first and additive-only within v1: enum value `DRAFT = 4`, request
  field `draft = 6`, one new RPC. Consumers regenerate at the composition boundary (T-0020 AC5).
- No readiness event this slice; SPEC-0064's open question names the follow-up.
