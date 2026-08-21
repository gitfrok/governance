# T-0081: Draft merge requests

- **Status:** Done (2026-08-21) — governance@39a2f1e+594aa40, backend@bed1194, bff@0d16824,
  webfrontend@71675e1; SPEC-0064 AC1–AC7 proven
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

## Exit record (2026-08-21)

Contract additive-only within v1: `MERGE_REQUEST_STATE_DRAFT = 4`, `bool draft = 6` on create,
`MarkMergeRequestReady` with the merge command's shape. Backend: a draft announces nothing,
receives no projections (the open lookups select `state = 'OPEN'`), cannot merge, accepts reviews,
and `MarkReady` re-reads both revisions from what Repository/Git announced before flipping to OPEN
under one version bump. BFF forwards the flag and serves `/ready`; the page renders a Draft pill
and swaps merge for mark-ready while the state lasts. Consumers regenerated at the composition
boundary (`make codegen-check` green). Backend suite 97 packages green with 0 skips; bff 17
packages; webfrontend 593 unit tests + typecheck + build.

## Notes / open questions

- Contract is governance-first and additive-only within v1: enum value `DRAFT = 4`, request
  field `draft = 6`, one new RPC. Consumers regenerate at the composition boundary (T-0020 AC5).
- No readiness event this slice; SPEC-0064's open question names the follow-up.
