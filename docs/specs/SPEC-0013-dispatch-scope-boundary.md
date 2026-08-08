# SPEC-0013: Dispatch scope boundary & worktree isolation

- **Status:** Proposed
- **Owner:** platform
- **Context(s):** process (governance + super-repo tooling — no runtime code)
- **ADRs:** 0037 (decision 5 deferred this "to its own task with its own spec"), 0027 (repo topology),
  0028 (AGDD), 0001 (ADR SoT)
- **Task(s):** —

## Problem / context

ADR-0037 adopted five typed personas and deliberately held back the sixth:

> **Six typed personas are adopted; the dispatcher's execution model is not — yet.** […] The
> **dispatcher** drives parallel worktree builds behind a pre-commit hook that enforces a *plan-phase*
> boundary; it knows nothing about invariant 23 (one commit never spans two submodules). Adopting it
> requires teaching that hook our topology.

Two things have changed since. The invariant-23 check now exists — `check-ceremony-tier.sh` detects a
diff spanning two submodule paths and is generated into all five repos. And the surrounding
machinery it would need (a canonical source, a drift gate, a tested fitness function) is in place
rather than hypothetical.

**What has not changed is whether the expensive half is worth building.** It is worth being blunt
about that here rather than discovering it after the code exists. The original framing is *parallel
batch dispatch*: fan several plan phases out into concurrent worktrees, each with session-scoped
state files, and merge the results. That solves contention between many simultaneous agents. This
project is one operator, and its dominant constraint is the opposite one — invariant 23 means a
change usually touches exactly one submodule, so the phases that could run in parallel are typically
in *different repos* and are already isolated by the repo boundary. Parallelism buys least where the
boundary is already hard.

The cheap half is worth building regardless, and it is separable: **a commit should not be able to
touch files outside the scope its plan phase declared.** That is true whether one agent is working or
six, it is enforceable locally by a git hook rather than by review, and the check it needs mostly
exists.

So this spec builds the boundary and stops short of the orchestrator, and says why.

## In scope

- A **declared scope** for a unit of work: the submodule it targets and the path globs it may touch.
- A **`pre-commit` hook** that rejects a commit touching anything outside that scope, installed into
  a working tree by an explicit command and never automatically.
- A **worktree helper** that creates an isolated git worktree for a piece of work inside one
  submodule, with the hook already installed and the scope recorded.
- Reuse of the existing invariant-23 detection rather than a second copy of it.
- A **`gitfrok-dispatcher` persona** whose job is to hold the scope, not to parallelise: it decides
  what a unit of work may touch, sets it up, and checks the result.

## Out of scope

- **Parallel batch execution.** Explicitly not built, per the reasoning above. If a future task shows
  contention between concurrent agents is a real cost here rather than an imagined one, that is when
  it earns a spec — and the boundary this one builds is its prerequisite either way.
- **Session-scoped transient state files.** They exist to keep concurrent dispatches from overwriting
  each other's handoffs. With no concurrent dispatch there is nothing to scope, and inventing the
  filenames now would be machinery in search of a user.
- Anything that weakens invariants 21–25, or lets a worktree commit span two submodules.
- Automatic hook installation. A hook that appears without being asked for is a hook people disable.

## Contracts touched

None.

## Data owned

The scope declaration is a file inside the worktree's `.git` directory, not in the tree. It describes
a working session, not the repository, and it must not survive into a commit.

## Design sketch

**Scope declaration.** One file, written by the helper, read by the hook:

```
repo:   backend
paths:  modules/policy/** internal/pep/** *_test.go
```

`repo` is the submodule the work targets — a hard fact, checkable against `.gitmodules`. `paths` are
globs relative to that repo's root. Absent a declaration the hook does nothing and says so, because a
hook that silently permits is indistinguishable from a hook that is not installed.

**The hook** runs on `pre-commit`, reads the staged file list, and rejects the commit if any staged
path matches no glob in `paths`. Its message names the offending file and the scope it violated, and
tells the user how to widen the scope deliberately rather than how to bypass the hook.

**Invariant 23** is checked by the same logic `check-ceremony-tier.sh` already uses, extracted into a
place both can call rather than copied. Copying it would be the exact drift ADR-0037 exists to
prevent, one level down.

**The worktree helper** creates `git worktree add` inside the target submodule on a new branch,
installs the hook, and writes the scope. It refuses if the target is not a submodule of this
composition, and it prints the path it made rather than changing the caller's directory.

**The persona** is generated like the other five, from `canonical/agent-surfaces/shared/`. Its role is
narrow: given a task, state the scope, set the worktree up, and verify afterwards that what was
committed matches what was declared. It orchestrates nothing.

## Acceptance criteria (each becomes a test)

- [ ] **AC1:** A commit staging a file matching a `paths` glob is permitted.
- [ ] **AC2:** A commit staging a file matching no glob is rejected, and the message names the file
      and the declared scope.
- [ ] **AC3:** With no scope declaration the hook exits 0 **and prints that it is inert**, so an
      uninstalled hook and a permitting hook are distinguishable in the log.
- [ ] **AC4:** The hook rejects a commit whose staged paths span two submodules, citing invariant 23,
      using the shared detection rather than its own copy.
- [ ] **AC5:** The worktree helper refuses a target that is not a submodule path in `.gitmodules`,
      naming the valid targets.
- [ ] **AC6:** The helper installs the hook and writes the scope such that a commit violating it in
      the new worktree fails without any further setup.
- [ ] **AC7:** The scope file is not committable — it lives under `.git/` and never appears in
      `git status`.
- [ ] **AC8:** Extracting the invariant-23 detection leaves `check-ceremony-tier.sh` behaviourally
      unchanged: its 13 existing cases still pass.

## Open questions

1. **Should the hook be advisory or blocking by default?** Blocking is the point, but a `pre-commit`
   hook is bypassable with `--no-verify` and always will be. The honest position is that this
   protects against mistakes, not against intent, and CI is the thing that protects against intent.
   Does that mean the same check also belongs in CI, where `--no-verify` cannot reach?
2. **Do scope globs belong in the plan, or only in the worktree?** In the plan they are reviewable
   before work starts; in the worktree they are trivially editable by whoever is working. Reviewable
   is better, but no plan format exists to put them in yet.
3. **Is `paths` worth it at all, or is `repo` the whole value?** Invariant 23 is the rule with teeth.
   A per-path scope catches a narrower class of mistake — touching an unrelated module in the right
   repo — and costs a glob list on every unit of work.
