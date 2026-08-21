# SPEC-0065: Merge strategies, and trunk-based landing as a mode

- **Status:** Approved (2026-08-21) — Accepted ADR-0088. Implementation not started.
- **Owner:** platform
- **Context(s):** git-storaged (commit-producing merges), Code Review (setting + command),
  contract `git/v1` and `codereview/v1` (additive), BFF, webfrontend.
- **ADRs:** 0088 (decides this), 0019, 0033/0016 (the durability path), 0085 (the floor holds)
- **Task(s):** T-0082 (backend)

## Problem / context

Merge means fast-forward today. Teams that expect merge commits, squash or linear history
discover the difference in their graph after the fact.

## In scope

- Per-repository strategy: `merge_commit` (default) | `squash` | `rebase`; `trunk_based` mode
  constraining to linear landing. Additive contract fields on the merge command and the setting.
- git-storaged produces commits: `merge-tree` for content merge and conflict detection,
  `commit-tree` for merge/squash commits; rebase only via a proven worktree-free or temporary-
  worktree path.
- Conflicts refuse before anything moves, with a machine-readable reason beside the coarse
  denial.

## Out of scope

- Signed merge commits (ADR-0083's custody trigger governs).
- Strategy per merge from a dropdown — refused by ADR-0088; the setting is the guarantee.
- Any widening of who may land: trunk mode constrains history shape only.

## Acceptance criteria (test-first)

- [ ] **AC1** Default is unchanged behaviour: a repository with no explicit strategy merges
      exactly as today (fast-forward when possible).
- [ ] **AC2** `merge_commit` lands a two-parent commit whose parents are target head and source
      head; authorship of source commits is preserved verbatim; committer identity is the
      platform's own service identity, never a caller's name.
- [ ] **AC3** `squash` lands exactly one commit whose tree equals the source head; the message
      defaults to the merge request title with the MR reference in a trailer.
- [ ] **AC4** `rebase` replays source commits onto the target head; the result is linear;
      a conflicting replay refuses the merge with nothing moved.
- [ ] **AC5** `trunk_based = true` refuses merge commits, prefers fast-forward, falls back to
      rebase, and still requires four eyes (ADR-0085) on every landing.
- [ ] **AC6** Every produced ref update takes the primary-plus-replica quorum path; a merge
      interrupted mid-write leaves no half-applied state (the ref either moved or did not).
- [ ] **AC7** The strategy is read server-side from the repository record at merge time; no
      caller field can choose it per request.

## Governance mapping

| Objective | How |
|---|---|
| G4 review integrity | Whatever the shape, landing passes the same gate: four eyes, protection rule, findings gate. |

## Open questions / assumptions

1. Rebase under concurrency is ADR-0088's named risk: if the bare-repository path cannot be
   proven sound against a racing push, `rebase` ships refused-per-repository rather than unsafe.
2. Merge-commit message conventions (trailers, sign-offs) are prose decisions deferred to
   implementation review.
