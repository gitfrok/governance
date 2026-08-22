# T-0082: Merge strategies, and trunk-based landing

- **Status:** Done (2026-08-21)
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

## Exit record (2026-08-21)

The default proof landed first (AC1): a repository with no explicit strategy
takes the legacy path in git-storaged — no plan on the wire, the same
compare-and-swap move as before, proven byte-for-byte by test. The conflict
proof followed (AC4): a diverged same-file fixture refuses with
`merge_conflict` on FailedPrecondition, the ref unmoved, zero events.

git-storaged produces commits through `merge-tree --write-tree` (content
merge into objects no ref points at), `commit-tree` under the service's own
identity for merge and squash landings, and `git replay --ref-action=print`
for rebase — probed once per process, refusing `rebase_path_unproven` where
the git is older than 2.44, exactly ADR-0088's named-risk escape hatch.
Trunk mode resolves server-side: fast-forward preferred, rebase fallback,
merge commits never. Every produced ref update takes the primary-plus-replica
quorum path (AC6); the RefUpdated event carries the landed revision.

Code Review reads the policy from the repository record at merge time
(SPEC-0065 AC7) — the merge command cannot express a strategy, proven by
tests over wired/unset/unreadable/no-reader compositions — and records a
refused landing's reason with the compensation on the audit trail. The
setting rides repository settings whole (`SetLandingPolicy`, repo.admin,
audited as `repository.landing.changed`); migration 0003 CHECK-refuses an
unknown strategy so an operator typo fails loudly instead of silently
degrading to fast-forward. Backend full suite green with the real-Postgres
lane at zero skips; bff regenerated additively, 17 packages green.

## Notes / open questions

- git-storaged owns the commit-producing work (`merge-tree`, `commit-tree`); Code Review composes
  and still saves before the move (ADR-0084 decision 3).
- ADR-0088's named risk is rebase under concurrency: if the bare-repo path cannot be proven
  sound against a racing push, ship `rebase` refused-per-repository rather than unsafe.
