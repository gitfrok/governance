# SPEC-0013: Dispatch scope boundary & worktree isolation

- **Status:** Approved (implemented)
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

- [x] **AC1:** A commit staging a file matching a `paths` glob is permitted.
- [x] **AC2:** A commit staging a file matching no glob is rejected, and the message names the file
      and the declared scope.
- [x] **AC3:** With no scope declaration the hook exits 0 **and prints that it is inert**, so an
      uninstalled hook and a permitting hook are distinguishable in the log.
- [x] **AC4:** The hook rejects a commit whose staged paths span two submodules, citing invariant 23,
      using the shared detection rather than its own copy.
- [x] **AC5:** The worktree helper refuses a target that is not a submodule path in `.gitmodules`,
      naming the valid targets.
- [x] **AC6:** The helper installs the hook and writes the scope such that a commit violating it in
      the new worktree fails without any further setup.
- [x] **AC7:** The scope file is not committable — it lives under `.git/` and never appears in
      `git status`.
- [x] **AC8:** Extracting the invariant-23 detection leaves `check-ceremony-tier.sh` behaviourally
      unchanged: its 13 existing cases still pass.

## Resolutions

**Approved 2026-08-09.** These were first answered by instruction and are now the approved design;
the record keeps the distinction because it changes what a later reader may assume was reviewed.


1. **Advisory or blocking? Both, and the CI half is the one that binds.** `git commit --no-verify`
   skips the hook and always will, so the hook stops mistakes and CI stops intent.
   `check-dispatch-scope.sh` runs on what was pushed rather than on what the author chose to run.

   It cannot read the hook's scope — that lives in a worktree's gitdir and is deliberately
   uncommittable (AC7) — so the declaration moves to the PR body, the same place the ceremony tier
   lives and for the same reason: it is what CI can actually read.

   ```
   Scope: backend modules/policy/** **/*_test.go
   ```

   **This closed a real gap rather than only duplicating the hook.** Invariant 23 is now checked
   unconditionally on every PR, declaration or not. Previously the only automated span check sat
   inside `check-ceremony-tier.sh`'s `bugfix` branch, so a `Ceremony: full` PR spanning two
   submodules passed CI unchecked — a hard rule guarded only when someone declared the lighter tier
   is a rule guarded backwards.

2. **Plan or worktree? Neither, in the end — the PR body.** The plan was the better answer and no
   plan format exists to hold it. The PR body is worse in one way the record should carry: after
   squash-merge the declaration lives in the PR rather than in git history, exactly as the ceremony
   tier does.

3. **Is `paths` worth it? Kept, on instruction, and still the weakest of the three.** `repo` is the
   rule with teeth and is now enforced unconditionally without any declaration at all. `paths` is
   opt-in and inert when absent — which is the honest shape for a check that catches a narrower
   class of mistake.

## Implementation

| File | Where | What |
|---|---|---|
| `dispatch-pre-commit.sh` | all five repos | the hook; installed only by the helper, never automatically |
| `check-dispatch-scope.sh` | all five repos | the CI half; invariant 23 always, path scope when declared |
| `lib-submodule-scope.sh` | all five repos | shared invariant-23 detection (AC8) |
| `dispatch-worktree.sh` | super-repo only | needs `.gitmodules` |
| `agent-dispatcher.md` | all five repos | the sixth persona |

All generated from `canonical/agent-surfaces/shared/` by the ADR-0037 pipeline. Tested by
`test-dispatch-scope.sh` (11 cases, hook) and `test-dispatch-scope-ci.sh` (9 cases, CI).

**One thing the implementation had to settle that the spec did not anticipate.** Globs are
submodule-relative, because that is what the hook sees — it runs inside the submodule. In the
composition the diff carries a `backend/` prefix the hook never encounters, so the CI check strips
it before matching. Without that the same declaration would mean two different things depending on
which side checked it, which is worse than not checking at all.

## What the implementation found

Four defects, all surfaced by running the gates and none by reading them. They are recorded here
because the spec's acceptance criteria did not predict any of them, and the shape is worth carrying
into the next checker of this kind.

| # | Defect | Fixed in |
|---|---|---|
| 1 | `for glob in $want_paths` word-splits **and pathname-expands**, so `.github/**` became whatever files existed at that directory's top level and stopped matching anything deeper | governance `243620a` |
| 2 | `rev-parse --git-path hooks` resolves against the **caller's** directory; the hook was installed into an unrelated tree | governance `bf24814` |
| 3 | A plain `sed` for `Scope:` matched the **example inside a fenced block in the gate's own PR body** and enforced it | governance `243620a` |
| 4 | `^sub$` counted a bare **gitlink** — mode `160000`, i.e. a pin bump — as a submodule span, so the gate rejected the very super-repo commit landing it and told the author to follow the ADR-0027 workflow it was refusing | governance `58ca605` |

Three share one shape: a shell construct that silently consults something other than what it appears
to — the filesystem, the caller's working directory, git's notion of what a path in a diff means.
The fourth is a parser handed its own documentation.

**The most useful finding is not any of the four.** All twenty tests passed while defect 1 was live,
because every fixture happened to expand to exactly the file under test — `src/**` in a repo whose
only `src` file was the one being checked. A fixture that cannot distinguish the mechanism from the
outcome is not testing the mechanism. Every case added afterwards was verified failing against the
unfixed code before being trusted.
