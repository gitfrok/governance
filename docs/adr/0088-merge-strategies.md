# ADR-0088: Merges are feature-based by default; trunk-based landing is a repository mode, not a second door

- **Status:** Accepted (2026-08-21, accepted as written by the deciding owner)
- **Date:** 2026-08-21
- **Deciders:** platform
- **Related:** SPEC-0019 (the merge this parameterises), git-storaged `MergeRef` (the ref move
  that becomes a commit-producing merge), ADR-0033/0016 (block volumes, durability quorum — the
  write path this rides), ADR-0085 (the floor every landing passes), ADR-0076 (settings scope)
- **Governs:** how the target ref advances when a merge request merges. Contract change is
  additive: one enum on the merge command and one field on the protection record.

## Context

A merge today fast-forwards the target ref to the head revision (`MergeRef` verifies the
revision exists and moves the ref; no commit is created). That is one history shape wearing the
name of all of them: no merge commits for teams that want feature history visible, no squash for
teams that want one commit per change, no rebase for linear-history teams. The user-visible
consequence is that "merge" silently means "fast-forward", and every team whose workflow assumes
otherwise discovers it in the graph.

## Decision

**1. A merge strategy is a per-repository setting with three values: `merge_commit` (default),
`squash`, `rebase`.**
- `merge_commit` — the target advances to a new commit with two parents (HEAD of target, head of
  source). Feature branches stay visible in history. This is the default because it changes
  nothing about what already landed and preserves authorship exactly as pushed.
- `squash` — the target advances to one new commit whose tree equals the source head; the source
  branch's commits collapse into it.
- `rebase` — the source's commits are replayed onto the target head and the target fast-forwards
  to the result. Linear history without invention.

**2. Trunk-based landing is a repository mode that can be enabled, not a separate strategy.**
`trunk_based = true` constrains the same MR door: merges must land linearly (fast-forward when
possible, otherwise rebase), merge commits are refused, and the four-eyes floor (ADR-0085) still
applies to everything. Trunk-based here is a *history discipline*, not a bypass — direct pushes
to the trunk ref remain governed by branch protection exactly as before.

**3. The commit-producing work lives in git-storaged**, which owns the bare repositories:
`git merge-tree` for content-level merges and conflict detection, `git commit-tree` for building
merge/squash commits, `git rebase` behind a temporary worktree only where a worktree is
unavoidable. Code Review composes the request and still moves first (ADR-0084 decision 3); the
ref update keeps the primary-plus-replica durability path every write takes.

**4. Conflicts fail the merge before anything moves**, with the refusal surfaced as the coarse
denial plus a machine-readable reason — the same shape as a moved-ref refusal. No half-applied
state exists: until the ref moves, nothing has happened.

## Consequences

**Good.** Teams get the history shape they already believe they configured. Squash gives the
revert-one-change story; trunk mode gives linear history without giving up review.

**Bad.** git-storaged starts creating commits, not just moving refs — committer identity,
timezone determinism and signed-commit questions arrive with it. Committer identity is the
platform's own (a git author is not a platform actor — check 12's rule, now on the producing
side); signing is explicitly out of scope until tenant custody gains a signing consumer
(ADR-0083's trigger list applies).

**The risk this ADR is most likely to be wrong about.** Rebase in a bare repository. If the
worktree-free path proves unsound under concurrency, the honest fallback is refusing `rebase`
per-repository until it is proven, not shipping a rebase that corrupts under a racing push.

## Alternatives considered

**Strategy chosen per merge from a dropdown.** Maximum flexibility, and no team can know what
history it will get — the property a repository setting exists to guarantee. Refused.

**Trunk-based as "allow direct pushes".** It would make the mode a hole in ADR-0085's floor.
Refused: the mode constrains history shape; it never widens who may land what.
