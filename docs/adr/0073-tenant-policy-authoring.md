# ADR-0073: Policy authoring in the product needs a per-tenant policy source, which governance does not have

- **Status:** Proposed
- **Date:** 2026-08-19
- **Deciders:** platform (found while scoping PR-27, ADR-0070 Tier B)
- **Related:** ADR-0001 (governance is the Source of Truth), ADR-0006 (deny-by-default PDP),
  ADR-0007, ADR-0053/0054 (how work lands), ADR-0070, ADR-0022
- **Governs:** PR-27 (policy authoring in the web UI), and PR-16's authoring half

## Context

PR-16 requires that a security or approval policy can be **authored, versioned, dry-run and
enforced**, with the deciding policy version recorded on the decision. Three of those four exist:
policies are versioned (the bundle carries a revision), dry-run is a contract surface
(`EvaluateDryRun`), and the deciding version is recorded on every decision record.

**Authoring is the one that does not, and the reason is structural rather than missing code.**
Policies live in `governance/policies/` as Rego, are checked by `check-policies.sh`, and ship as a
single signed OPA bundle at a revision. There is one bundle for the platform. `PolicyDecisionPoint`
exposes `Decide`, `EvaluateDryRun` and `GetDecision` — and nothing that writes.

That is not an oversight. **ADR-0001 makes governance the Source of Truth**, and policy is governance
in the most literal sense the repo has: it is the machine-readable form of what the platform will
and will not permit. A web form that writes policy is a second source of truth for the same
decisions, and the question of which one wins is not a UI question.

So PR-27 as written — *a policy owner can author, version, dry-run and enforce a policy from the web
UI* — cannot be built without first deciding **what a tenant-authored policy is**, and specifically:

- whether it is Rego at all, or a constrained form the product owns and compiles;
- how it composes with the platform bundle: is a tenant policy *additional restriction only*, or can
  it permit something the platform bundle denies? (Deny-by-default says the first, loudly.)
- what "versioned" means when the source is a database row rather than a git commit;
- how it is signed, or whether it is, given ADR-0044/ADR-0065's release-trust posture;
- what happens to in-flight decisions when a tenant edits a policy;
- and how it stays reviewable, since `check-policies.sh` gates the repo's bundle and would gate
  nothing here.

## Decision

**This ADR does not decide those questions. It records that PR-27 cannot proceed without them, and
it fixes one boundary so the eventual answer starts in the right place.**

**1. A tenant-authored policy may only ever narrow, never widen.** Whatever form it takes, it
composes with the platform bundle as additional restriction. A tenant policy that permits what the
platform bundle denies is not a policy, it is a privilege escalation with a form around it.
Deny-by-default (ADR-0006) already implies this; stating it here means the eventual design starts
from it rather than discovering it.

**2. Until the form is decided, the product ships the READ half of PR-16 and says the write half is
absent.** A policy owner can see which policies are in force, at which revision, and what a decision
cited — all of which is real, already recorded, and currently invisible. The surface says plainly
that authoring happens in governance, because that is true and a reader who believes otherwise will
go looking for a button that is not there.

**3. Dry-run is exposed as a read against the CURRENT bundle, not against a draft.** `EvaluateDryRun`
answers "what would this policy decide about this input" for the policy that exists. That is useful
and honest. Dry-running a *draft* requires the draft to exist, which is the whole open question.

## Consequences

**Good.** The genuinely useful and genuinely safe half of PR-16 — seeing what is in force and what
decided a given outcome — stops being invisible. The dangerous half is not built by accident, and
the narrowing rule is on record before anyone designs a form.

**Bad.** PR-27 is not delivered. A compliance owner who was promised policy authoring in the product
gets a read-only view and a pointer at a git repository, which for a non-engineer is close to no
answer at all. That gap is real and this ADR does not close it.

**The risk this ADR is most likely to be wrong about.** That "author policy in governance" is an
acceptable answer for the intended user. PR-16's own persona is a *compliance owner*, and the wedge
this product sells is that compliance work stops requiring engineers. Telling that person to open a
pull request against a Rego bundle may be exactly the thing the product exists not to do. If so,
this deferral is not caution — it is the product declining its own premise, and the log-ADR argument
in ADR-0072 applies here twice over.

## Alternatives considered

**Write Rego from a web form into the governance repo.** Refused for now, but the most honest
option on the table: it keeps one source of truth and one review path. It needs a decision about
how a tenant gets commit access to a platform repository, which is a larger question than it looks.

**A per-tenant Rego bundle, layered under the platform's.** The likely shape of the eventual answer.
Deferred because "layered" hides every hard question in this ADR's context section.

**A constrained policy form the product owns.** Attractive for the compliance-owner persona, and the
most work: a form that cannot express escalation, compiled to Rego, versioned as data. It is a
product in itself.

## Follow-ups

- The per-tenant policy source decision, starting from decision 1's narrowing rule.
- Whether the compliance-owner persona is served at all by "author in governance", which is a
  product question this ADR raises and does not answer.
