# ADR-0054: `main` is guarded against rewrite and deletion, and against nothing else

- **Status:** Accepted
- **Date:** 2026-08-12 (proposed and accepted the same day)
- **Deciders:** platform
- **Governs:** G7 process integrity (the gates must be real, or not claimed)
- **Supersedes:** ADR-0053 (which superseded ADR-0031) — the working mode is unchanged; the reason and
  the mechanism are
- **Relates to:** ADR-0027, ADR-0028 · **Invariants:** 23, 24, 25 — **unchanged** · **Tasks:** T-0002

## Context

ADR-0053 moved this tree to direct-to-`main` and gave two reasons: the review requirement cost more
than it caught, and — the load-bearing one — the repos had gone private on a plan where GitHub offers a
private repo neither rulesets nor branch protection, so ADR-0031's enforcement could not be applied or
verified at all.

**That second reason is gone. The five repos are public again, so rulesets work here.** Enforcement is
available, which means the mode is now a choice rather than a consequence, and an ADR that justifies a
choice by a limitation that no longer exists is the kind of stale reasoning ADR-0001 exists to stop.

The first reason stands and is now the whole of it: **the four-eyes requirement is removed
deliberately.** It was a human gate on a tree worked by one maintainer and an agent, and stale-review
dismissal meant every follow-up push invalidated the approval before it, so a single session spent
three approval rounds on three pull requests without a round finding anything.

What the repos actually carried when they came back public is worth recording, because it was neither
state: both ADR-0031 rulesets were still `active` in all five repos with zero bypass actors,
`main-review` had been edited down to `required_approving_review_count: 0`, and **both still carried a
`pull_request` rule.** So four-eyes was genuinely gone while a pull request was still mandatory — the
one shape nobody had chosen, and one that forbids the very pushes ADR-0053 made the normal path.

Three options for a public repo under this mode:

**Nothing at all.** `main` would be force-pushable and deletable by anyone with write access. Neither
is ordinary work; both destroy history that other clones and every submodule pin depend on.

**Restore required status checks.** GitHub evaluates those when a pull request merges. With direct
pushes allowed they gate nothing, so listing them would advertise a protection that is not there —
exactly the failure this ADR chain has been correcting.

**Guard the two things that are never ordinary work, and nothing else.**

## Decision

1. **One ruleset per repo, `main-guard`, on the default branch:** `non_fast_forward` and `deletion`.
   No bypass actors, `enforcement: active`.

2. **No pull-request requirement and no required status checks.** A push to `main` remains the normal
   way work lands (ADR-0053 decision 1, unchanged), and CI on push remains the only gate (decision 2,
   unchanged). A rule demanding a pull request would forbid the mode; a required check would not fire
   for a push and would misrepresent what is enforced.

3. **`main-integrity` and `main-review` are deleted, not disabled.** A dormant ruleset nobody reads is
   how a tree comes to claim a gate it does not have. `apply-rulesets.sh` removes them by name and
   `check` asserts they stay gone, and asserts no `pull_request` rule reappears in `main-guard` —
   reinstating ADR-0031's gate needs an ADR, not an edit in the web UI.

4. **The four-eyes requirement is removed by decision, not by platform limitation.** Anyone wanting a
   second pair of eyes on a particular change opens a pull request for it; that remains available and
   is a choice.

5. **Everything else ADR-0053 decided stands**: local gates run before the push because they are the
   last check before something is permanent, a red `main` is a stop-everything condition, invariants
   23–25 are untouched, and SPEC-0012's ceremony tier lives in a `Ceremony:` commit trailer whose gate
   is still inert until taught to read a commit.

## Consequences

**Positive.** `main`'s history cannot be rewritten or deleted by accident, which is the one protection
that was worth having and the one that costs nothing under this mode. The tree's claims match the API
again: `make rulesets-check` verifies the guard and fails if a pull-request rule returns.

**Negative.** Unchanged from ADR-0053: nothing mechanically stops a bad commit reaching `main`, and
there is no second pair of eyes unless someone asks. Recovery is `git revert`, which the guard
deliberately leaves possible while forbidding the rewrite that would hide the mistake instead.

**Neutral.** If the repos ever go private again on this plan, `apply-rulesets.sh` reports the mechanism
unavailable and exits 0; the working mode does not depend on it.

## Alternatives

Rejected above: no protection at all, and required status checks that would not fire. Also rejected:
keeping the rulesets and merely emptying their rules, which leaves two objects whose names promise
enforcement they no longer carry.
