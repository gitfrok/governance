# T-0082: Merge strategies, and trunk-based landing

- **Status:** Not started
- **Phase / Epic:** EP-30 (the review loop, completed)
- **Repo(s):** governance, backend
- **Spec:** ../specs/SPEC-0065-merge-strategies.md (AC1–AC7)
- **ADRs:** 0088, 0019, 0033, 0016, 0085
- **Owner:** unassigned

## Goal

A merge lands in the history shape the repository chose: merge commit, squash or rebase — with
trunk-based landing as a mode that constrains shape, never review.

## Acceptance criteria (test-first)

- [ ] SPEC-0065 AC1–AC7 — as written in the spec.

## Tests to write first

- The default proof (AC1): a repository with no strategy merges exactly as today, byte-for-byte —
  the setting's absence must not change what already works.
- The conflict proof (AC4): a conflicting rebase/merge refuses with the ref unmoved and no
  objects reachable only from the failed attempt.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- git-storaged owns the commit-producing work (`merge-tree`, `commit-tree`); Code Review composes
  and still saves before the move (ADR-0084 decision 3).
- ADR-0088's named risk is rebase under concurrency: if the bare-repo path cannot be proven
  sound against a racing push, ship `rebase` refused-per-repository rather than unsafe.
