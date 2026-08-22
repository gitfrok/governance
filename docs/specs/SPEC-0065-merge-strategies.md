# SPEC-0065: Merge strategies, and trunk-based landing as a mode

- **Status:** Implemented (2026-08-21) — T-0082; contract, backend proven. Approved (2026-08-21)
  under Accepted ADR-0088.
- **Owner:** platform
- **Context(s):** git-storaged (commit-producing merges), Code Review (setting + command),
  contract `git/v1` and `codereview/v1` (additive), BFF, webfrontend.
- **ADRs:** 0088 (decides this), 0019, 0033/0016 (the durability path), 0085 (the floor holds)
- **Task(s):** T-0082 (backend)

## Problem / context

Merge means fast-forward today. Teams that expect merge commits, squash or linear history
discover the difference in their graph after the fact.

## Implementation notes

1. **AC1 read literally: unset means legacy.** The strategy column's default is the empty string,
   not `merge_commit` — a repository whose landing policy was never set merges byte-for-byte as
   before (fast-forward when possible). "Default" in ADR-0088's scope line names the recommended
   choice for repositories that opt in; AC1 pins migration safety, and migration safety wins.
2. **Trunk mode is resolved server-side at storage**, in one atomic call: fast-forward preferred,
   squash kept (it lands linearly), everything else falls back to rebase; a merge commit is never
   produced under trunk mode whatever asked for it (AC5). The object graph is storage's fact; Code
   Review only forwards what the record holds (AC7 by construction — the merge command cannot
   express a strategy).
3. **Rebase rides `git replay --ref-action=print`** (git ≥ 2.44), the worktree-free replayer that
   names what it would update without touching any ref; the only ref move remains MergeRef's own
   compare-and-swap. The capability is probed once per process; where git is older, rebase refuses
   per landing with `rebase_path_unproven` rather than shipping unsafe (ADR-0088's named risk,
   taken exactly as written).
4. **Refusals are machine-readable beside the coarse denial**: conflicts refuse before anything
   moves with `merge_conflict`, an already-contained source with `up_to_date`, on FailedPrecondition;
   Code Review records the reason with the compensation on the audit trail.

## Acceptance criteria (test-first)

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

- [x] **AC1** Default is unchanged behaviour: a repository with no explicit strategy merges
      exactly as today (fast-forward when possible).
- [x] **AC2** `merge_commit` lands a two-parent commit whose parents are target head and source
      head; authorship of source commits is preserved verbatim; committer identity is the
      platform's own service identity, never a caller's name.
- [x] **AC3** `squash` lands exactly one commit whose tree equals the source head; the message
      defaults to the merge request title with the MR reference in a trailer.
- [x] **AC4** `rebase` replays source commits onto the target head; the result is linear;
      a conflicting replay refuses the merge with nothing moved.
- [x] **AC5** `trunk_based = true` refuses merge commits, prefers fast-forward, falls back to
      rebase, and still requires four eyes (ADR-0085) on every landing.
- [x] **AC6** Every produced ref update takes the primary-plus-replica quorum path; a merge
      interrupted mid-write leaves no half-applied state (the ref either moved or did not).
- [x] **AC7** The strategy is read server-side from the repository record at merge time; no
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
