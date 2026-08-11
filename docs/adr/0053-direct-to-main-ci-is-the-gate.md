# ADR-0053: Work lands directly on `main`; CI on push is the only gate

- **Status:** Superseded by ADR-0054
- **Date:** 2026-08-12 (proposed and accepted the same day)
- **Deciders:** platform
- **Governs:** G7 process integrity (the gates must be real, or not claimed)
- **Supersedes:** ADR-0031 (split merge enforcement via two rulesets)
- **Relates to:** ADR-0027 (repo topology), ADR-0028 (AGDD) · **Invariants:** 23, 24, 25 —
  **unchanged** · **Tasks:** T-0002 (AC5)

## Context

ADR-0031 replaced legacy branch protection with two rulesets — `main-integrity` (PR required,
required checks, no bypass actors) and `main-review` (one approving review) — and its reasoning rested
on one stated fact: *"All five repos are public (rulesets are available to public repos on the Free
plan)."*

**That premise no longer holds. The five repos are private, and this plan gives a private repo neither
rulesets nor branch protection.** Both endpoints answer:

```
GET /repos/gitfrok/gitfrok/rulesets            403 Upgrade to GitHub Pro or make this repository public
GET /repos/gitfrok/gitfrok/branches/main/protection  403 Upgrade to GitHub Pro or make this repository public
```

So the mechanism ADR-0031 specified cannot be read, applied, or verified here. `make rulesets-check`,
the gate ADR-0031 named to guard its own gates, cannot function. Whatever `main` enforces today,
nothing in this tree can assert it — and a gate nobody can verify is exactly what ADR-0034 and
ADR-0036 were written about, in a different domain.

The review half also cost more than it caught. Stale-review dismissal means every follow-up push
silently invalidates the approval that preceded it, so a single session's work took three approval
rounds on the same three pull requests while the diffs were being corrected — and each round was a
human waiting on a second account, not a reviewer finding anything. The findings in that session came
from CI and from an adversarial read of the diff, both of which happen whether or not a pull request
exists.

Two shapes were considered.

**Keep pull requests as a convention with nothing enforcing them.** Honest about the mechanism but
dishonest in effect: the documents would still read as if `main` were guarded, and the next agent
would treat "four-eyes review is mandatory, there is no `--admin` path" as a fact when it is a
courtesy. The tree already had that shape once, in the `enforce_admins=false` state ADR-0031 was
written to end.

**State that work lands on `main`, and make CI the gate that actually exists.** The workflows already
run on `push` to `main` in every repo. What changes is when they speak: a red build reports on a
commit that is already there rather than blocking one that is not.

## Decision

1. **Work lands directly on `main` in every repo.** No pull request and no approving review is
   required. A pull request remains available for anything worth discussing before it lands — a
   contested design, a large migration — and is a choice, not a gate.

2. **CI is the gate, and it is the *only* gate.** Every repo's workflow runs on push to `main`. A red
   `main` is a stop-everything condition: the next commit fixes it or reverts it, and no other work
   proceeds until it is green. This is the whole of what replaces the required check.

3. **The local gates run before the push, not after.** `make verify`, the repo's own tests, and the
   fitness functions are the last check that happens *before* something is permanent. Under ADR-0031
   a red check merely blocked a merge; now it blocks nothing, so running it first is not diligence but
   the mechanism.

4. **Invariants 23, 24 and 25 are untouched.** One commit never spans two submodules; cross-repo work
   still goes governance → consumer → super-repo; the super-repo still stores pins, moved in their own
   commit, to commits that exist on the submodule's `main`. Those are properties of commit shape and
   ordering, not of pull requests, and nothing here relaxes them.

5. **SPEC-0012's ceremony tier is declared in the commit message** (`Ceremony: full|quick|bugfix`,
   its own trailer line) rather than in a pull-request body. `check-ceremony-tier.sh` reads
   `PR_BODY`, so it is **inert on a push** until it is taught to read the commit — wiring that is the
   follow-up this decision owes, and it is recorded rather than assumed.

6. **`apply-rulesets.sh` is kept and made honest.** It reports that the mechanism is unavailable on
   this plan instead of failing as if it had drifted, so the day the repos go public or the org gets
   Team, restoring enforcement is one command rather than an archaeology exercise.

## Consequences

**Positive.** The documents describe what is actually true, which is the property ADR-0001 exists to
protect. A correction lands in the time it takes to run the tests, rather than in the time it takes a
second account to re-approve a diff it had already approved. The gates that ever found anything here —
CI, the fitness functions, adversarial review of a diff — all still run.

**Negative, and it is a real loss.** Nothing mechanically prevents a bad commit from reaching `main`.
There is no second pair of eyes unless someone asks for one, and no red check standing between a
mistake and the default branch. The mitigation is entirely procedural: local gates before the push, a
red `main` treated as an emergency, and `git revert` as the ordinary correction. Anyone uncomfortable
with that for a particular change should open a pull request for it, which decision 1 keeps available.

**Neutral.** The four-eyes claim disappears from the tree rather than being quietly falsified. T-0002
AC5 ("CI runs these on every PR and blocks merge on violation") is met in spirit and not in letter:
the checks run on every push, and there is no merge to block.

## Alternatives

Rejected above: keeping pull requests as an unenforced convention. Also considered and rejected:
buying GitHub Pro or Team purely to restore the rulesets — that is a spending decision this ADR has no
standing to make, and it is available later without any change to the code, since decision 6 keeps the
script that would apply them.

## Open questions

- Teaching `check-ceremony-tier.sh` to read the tier from a pushed commit's message, so decision 5's
  declaration is checked rather than merely written.
- Whether a red `main` should notify anything beyond the person who pushed it.
