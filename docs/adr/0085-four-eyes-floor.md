# ADR-0085: Every merge lands through review, and the floor is four eyes

- **Status:** Accepted (2026-08-21, accepted as written by the deciding owner)
- **Date:** 2026-08-21
- **Deciders:** platform
- **Related:** SPEC-0019 (the approval gate this raises), ADR-0029 §4 (imported approvals never
  count), ADR-0006 (the PDP decides), ADR-0073 (the narrow-only pattern for tenant-facing policy),
  the M11 lesson in `../plans/phase-2-ultimate-wedge.md` (thresholds live in the bundle)
- **Governs:** `merge_request.merge` admission, platform-wide. No contract change — the facts the
  gate consumes already exist on the decision input.

## Context

The approval gate today is relative: a merge needs `valid_approvals >= required_approvals`, and
`required_approvals` comes from the target ref's branch-protection rule — where **zero is legal**.
A merge into an unprotected ref needs no approval at all, and one approving reviewer satisfies
every protected ref configured with `required_approvals = 1`. The author can be the second pair of
eyes on their own change: `validApprovals` counts every first-party approval at the head revision,
the author's included.

The product's control story is that changes land through review. A floor of zero approvals on an
unprotected target, and self-approval counting toward the requirement, are both holes in that story
that no per-repo configuration closes, because both come from what the *absence* of configuration
means.

## Decision

**1. The platform enforces a four-eyes floor: two approvals from people who are not the author,
on every merge, protected target or not.** Tenants raise the bar per ref through
`required_approvals`; nothing lowers it below two.

**2. The author's own review never counts.** The server excludes the MR creator's review before
assembling `valid_approvals`. The review itself is still recorded — it remains review activity,
and its audit record stands (SPEC-0019 AC6) — it just never satisfies the gate. No wire change:
the exclusion happens before the fact exists.

**3. The floor lives in the policy bundle, beside `required_approvals`, not in a service
constant.** This is the M11 lesson applied to our own rule: a threshold mirrored in Go is a
threshold one refactor away from diverging. The bundle already sees every merge decision; the
floor is a second inequality in `sufficient_approvals`.

**4. Direct pushes are unchanged.** Protecting a ref already denies them; a tenant that wants
MR-only landing protects its refs. The floor governs the MR door, which is now genuinely the only
reviewed door.

## Consequences

**Good.** No merge lands on fewer than two people's judgment, and never the author's alone among
them. The property holds for every tenant by default instead of by configuration discipline.

**Bad / behaviour change.** Every existing flow that merged with one approval now needs two; the
dev journeys and the composition harness's ALLOW fixtures move from "2 of 1" being generous to
being exactly the floor. Tests asserting single-approval merges were updated with the rule.

**The risk this ADR is most likely to be wrong about.** Small teams: a two-person tenant cannot
merge at all until a third account approves or the author merges nothing. That is the floor doing
its job, but if it bites real tenants, the honest fix is a tenant-level exception decided by an
ADR — not a quiet lowering of the constant.

## Alternatives considered

**Floor only on protected refs.** Keeps unprotected targets friction-free — and keeps the hole:
the refs nobody remembered to protect are the ones solo-merged at 2am. Refused.

**Refuse the author's review outright.** Clearer intent, but it turns a harmless "I approve my own
typo fix" into an error and loses the review record; not-counting achieves the gate property
without changing what a review is.

**Per-repo opt-in flag.** Configuration discipline again — the thing this ADR exists to stop
depending on.
