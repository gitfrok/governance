# ADR-0031: Split merge enforcement — bind admins to checks, keep review bypassable

- **Status:** Accepted
- **Date:** 2026-08-04
- **Deciders:** platform
- **Governs:** G7 process integrity (CI gates cannot be bypassed)
- **Relates to:** ADR-0027 (repo topology), ADR-0028 (AGDD) · **Invariants:** 24, 25 ·
  **Tasks:** T-0002 (AC5), T-0009 · **Closes:** the "second GitHub org member" parked item

## Context

T-0002 AC5 reads: *"CI runs these on every PR and blocks merge on violation."* Today it **runs**
on all three CI repos and **blocks nothing**, because every repo uses legacy branch protection with
`enforce_admins=false`. Verified on 2026-08-04 against `gitfrok/gitfrok`: `enforce_admins: false`,
1 required approving review, required check `super-repo fitness gates`. A repo admin's
`git push origin main` succeeds and `gh pr merge --admin` bypasses both the check and the review.

Legacy branch protection has **one** admin-binding switch for all of its rules. Turning
`enforce_admins=true` binds admins to the required *review* as well as the required *checks*, and
the `gitfrok` org has a single member (`dearteno`, Free plan, 1 filled seat). GitHub forbids
self-approval, so binding admins today makes `main` unmergeable. That is the deadlock recorded in
T-0002 and in the backlog's parked list, and the decision noted there was "add a second org member,
then bind admins" — which makes closing EP-0 wait on hiring or inviting a person.

Two facts change the shape of that trade:

1. **AC5 is about checks, not about review.** Its wording is "CI runs these ... and blocks merge on
   violation". A required approving review is a good practice we chose independently; it is not what
   AC5 asks for, and it is the *only* half of the pair that a single-member org cannot satisfy.
2. **Rulesets have per-ruleset bypass lists.** All five repos are public (rulesets are available to
   public repos on the Free plan) and none has a ruleset today — `rulesets` returns 0 on every repo.
   Two rulesets can therefore carry *different* bypass sets, which legacy protection cannot express.

So the coupling that produced the deadlock is an artifact of legacy branch protection, not something
inherent to the goal.

## Decision

We will replace legacy branch protection on `main` in all five repos with **two rulesets**, so that
admin bypass is scoped to the human gate and never to the machine gate:

| Ruleset | Rules | Bypass actors |
|---|---|---|
| **`main-integrity`** | pull request required (0 required approvals), required status checks (per `ci-gates.md`), block force-push, block deletion, require conversation resolution | **none** |
| **`main-review`** | 1 required approving review, dismiss stale approvals | Repository admin |

The machine gate becomes genuinely unbypassable — no `--admin` merge, no direct push, no admin
exemption — which is exactly AC5. The review requirement stays declared and enforced for every
non-admin, and stays bypassable **only** while the org has one member. Adding a second member is
then a normal onboarding step, not a release blocker: when one exists, we remove `Repository admin`
from `main-review`'s bypass list and both gates are absolute.

Three constraints on this:

- **`main-integrity` never gains a bypass actor.** A change to its bypass list is a PR against this
  ADR. Adding one re-opens AC5 by definition.
- **Repos with no required checks still get `main-integrity`.** Verified 2026-08-04: required checks
  are wired on the super-repo (`super-repo fitness gates`), `backend` and `bff` (`build + vet + arch
  gates`). `governance` runs a docs gate (T-0009) that is **not** in its required-check list, so a red
  gate does not block today; `webfrontend` has no workflow at all. Both still get `main-integrity` for
  the parts that do not depend on CI — PR-only, no force-push, no deletion. A repo is not exempt from
  the mechanism because its check list is empty.
- **The bypass on `main-review` is time-boxed by a condition, not a date:** the second org member.
  It is recorded as a follow-up here and in T-0002, not left implicit in a GitHub setting.

## Consequences

**Positive:** AC5 closes on the strength of the enforcement it actually names, so EP-0 stops waiting
on an org headcount action. Every fitness function, arch gate and dep-direction check that T-0002
and T-0009 built becomes load-bearing rather than advisory — today a tired admin can merge past all
of them with one flag. The two-ruleset split also survives growth: the review gate tightens by
deleting one bypass entry, with no re-plumbing.

**Negative / costs:** for as long as the org has one member, `main` has no four-eyes review — a solo
admin can open a PR and merge it once checks are green. That is a real reduction against the *stated*
policy, though not against the *effective* one, which is what `enforce_admins=false` already allows
anywhere. Rulesets are also a second mechanism to understand alongside legacy protection; we mitigate
that by removing legacy protection rather than layering the two, since overlapping rules are
evaluated as a union and the most permissive bypass wins, which is confusing precisely where it
matters most. Org-level rulesets need Team/Enterprise, so these are per-repo and must be applied
five times — a scripting job, and drift between repos becomes possible.

**Follow-ups:**
- Add a second org member; then drop `Repository admin` from `main-review` bypass on all five repos
  and note it in T-0002. Until then the gap above is the known, accepted cost.
- Script the ruleset application (`scripts/` in the super-repo) so the five repos cannot drift, and
  consider a fitness check asserting `main-integrity` exists with an empty bypass list on each repo —
  the gate that guards the gates.
- `governance`'s docs gate (T-0009) is active but not required — add it to `main-integrity`'s
  required checks so the SoT repo's own gate blocks like every other. `webfrontend` needs a workflow
  before it has anything to require (`ci-gates.md` lists lint/format, unit, E2E and arch for it).
- Revisit if the org moves to Team: org-level rulesets would replace the five per-repo copies.

## Alternatives considered

- **Add a second org member first, then set `enforce_admins=true`** (the decision recorded in
  T-0002) — not rejected, deferred: it is the *end state* this ADR keeps as a follow-up. Rejected
  only as the *precondition*, because it makes a code-quality gate wait on an unrelated org action,
  and EP-0 has been open on it since T-0002 landed.
- **Set `enforce_admins=true` now and drop the required review to 0 on legacy protection** —
  rejected: it reaches the same enforcement but deletes the review policy instead of scoping its
  bypass, so restoring four-eyes later means re-deciding it rather than deleting one entry. It also
  leaves no record of *why* the review count is 0.
- **A machine/bot account as the second member to supply approvals** — rejected: an approval nobody
  read is worse than a declared exemption, because it makes the audit trail claim a review happened.
  It also adds a credential to hold for no review value.
- **Leave `enforce_admins=false` and rely on discipline** — rejected: it is the status quo, and it
  makes every gate T-0002/T-0009 built optional at the exact moment someone is in a hurry. An
  unenforced gate is documentation.
- **Require checks but allow direct pushes to `main`** — rejected: status checks are evaluated
  against a PR, so allowing direct pushes routes around them entirely rather than loosening them.
