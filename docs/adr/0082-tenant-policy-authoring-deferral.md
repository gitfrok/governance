# ADR-0082: Tenant policy authoring remains deferred — the reopen trigger is a tenant with a name, not a row in the PRD

- **Status:** Accepted (2026-08-21, accepted as written by the deciding owner)
- **Date:** 2026-08-20
- **Deciders:** platform (drafted under the standing instruction to give ADR-held deferrals their own
  ADR; accepted by the deciding owner 2026-08-21)
- **Related:** ADR-0001 (governance is the Source of Truth), ADR-0006 (deny-by-default PDP),
  ADR-0007, ADR-0070 (the tier gate whose philosophy this applies), ADR-0072 (the deferral pattern
  this follows), ADR-0073 (the deferral this revisits)
- **Governs:** PR-27 (policy authoring in the web UI), and PR-16's authoring half under reading B

## Context

Three records describe the same absence, and they agree.

**SPEC-0029's fork.** Phase 2 settled PR-16 at approval on **reading A**: policy stays reviewed
Rego in `governance/policies`, git is the version store, and the recorded deciding version is the
bundle revision. **Reading B** — in-product per-tenant authoring — was recorded as "a second
mutable policy source" that "requires a Proposed ADR before any contract work." This is that ADR.

**ADR-0073** found authoring absent *structurally*, not missing: policies are governance in the
most literal sense the repo has, ADR-0001 makes governance the Source of Truth, and a web form
that writes policy is a second source of truth for the same decisions. It enumerated the open
questions — the form of a tenant policy, its composition with the platform bundle, versioning
without git, signing, in-flight decisions, reviewability — decided none of them, and fixed one
boundary: **a tenant-authored policy may only ever narrow, never widen.**

**Phase 4** delivered the read half ([SPEC-0055](../specs/SPEC-0055-policy-visibility.md),
T-0062/T-0063) and recorded that "PR-27's authoring is NOT delivered — a deferred decision with
its own ADR, held by a contract gate rather than by intention"
(`../backlog/README.md`, EP-26). The gate is check 14 in `../../scripts/check-contracts.sh`:
`gitsaas.policy.v1` carries no authoring verb, asked of the compiled descriptor and paired with a
fixture, so the deferral is a type property (SPEC-0055 AC2), not a note.

**What has changed on the demand side since those records: nothing.** There is no tenant, no
design-partner request, and no measured cost of the governance-PR path on anyone. PR-27's evidence
lineage is a prototype screen, adopted by ADR-0070 as a Tier-B row citing PR-16 — and PR-16 itself
is Implemented under reading A, so the GA bar ([PRD](../product/PRD.md) §10: PR-1…PR-19 shipped)
is met on the approved reading. What remains unmet is specifically the *in-product* surface, and
every recorded argument for it is the premise argument — the compliance owner who should not need
an engineer — not a request from one.

**What has not changed on the cost side either.** ADR-0073's open questions all stand, and a
second policy source drags the rest of a bounded context with it: tenant-scoped storage and RLS,
an authoring verb vocabulary the PDP must authorize, audit obligations, residency, and metering.
ADR-0070's consequences name the price of exactly this class of adoption: each such surface
"widens the audit, permission and residency surface permanently."

The control plane's topology summary (`../agents/context.md`) lists "policy authoring" among its
concerns; under reading A that authoring happens in this repo and ships as the signed bundle the
data plane loads, so the line is satisfied without a per-tenant surface.

## Decision

**1. Tenant policy authoring is not built now.** Reading A remains the only authoring path. The
product keeps shipping SPEC-0055's read half and saying plainly where authoring happens, because
that is true. PR-27 stays open — neither delivered in part nor withdrawn.

**2. The deferral keeps being held by construction, not by intention.** Check 14 stays as written;
an authoring verb arriving in `gitsaas.policy.v1` before this decision is reopened and Accepted is
the gate failing, exactly as SPEC-0055 AC2 authored it. ADR-0073's narrowing rule is Accepted and
binds every future shape; nothing here loosens it.

**3. The reopen trigger is a named tenant need, and either of these is one.**

- A design partner or tenant asks to change a security or approval policy **without going through
  vendor review** — demand with a name and a date on it.
- Reading A's governance-PR path becomes a **measured bottleneck** for tenant-specific rules:
  change requests queue against the platform team, or turnaround gets complained about. That is
  the persona failure SPEC-0029's fork was designed to avoid, observed instead of predicted.

Not a trigger: the prototype, the PRD row, another forge shipping it, or internal convenience.
ADR-0070's gate philosophy is the reason — scope is defended on its merits at decision time, and a
mockup or a PRD row is not a customer.

**4. When the trigger fires, the reopened decision starts from ADR-0073's boundaries, not from a
blank page.** The narrowing rule binds; the layered per-tenant bundle is the presumptive shape to
beat; and the answer must say what the *deciding version* means once a second source exists —
every decision records the bundle revision today (SPEC-0029 AC1), and the day a tenant source
exists, evidence citation (G6) needs the record to name source **and** revision together, or "what
decided this" stops having one answer for an auditor.

**5. On acceptance, the PRD gets the annotation its sibling deferrals carry.** PR-27's Phase-4 row
and §12.1 gain the "Closed as deferred — held by check 14" record the way PR-29, PR-30 and PR-31
carry theirs. The backlog's fork record carries a pointer from this proposal; the PRD is amended at
acceptance, not by a Proposed ADR.

## Consequences

**Good.** A second source of truth is not built on zero demand. The deferral stops being an
open-ended drift: it has a trigger someone can observe, a shape it must start from, and a gate
that fails loudly if it erodes. And the tier gate's record stays consistent — every Tier-C ADR
narrowed or refused the surface its mockup drew; this applies the same standard to a row whose
demand evidence is the row.

**Bad.** PR-27 stays open, and the persona problem ADR-0073 raised is parked, not solved: the
compliance owner is still told to ask the vendor to review Rego. If demand arrives tomorrow, the
critical path is long, because the open questions this ADR declines to answer on speculation are
the same ones that must be answered then.

**The risk this ADR is most likely to be wrong about.** The same bet ADR-0073 flagged — that
"author in governance" is an acceptable answer for the person the product exists to serve — with
one addition: the trigger may be too passive. Pre-GA the only demand channel is the design-partner
conversation (PRD §10), and demand can surface as a lost evaluation — *we'd have to keep asking
the vendor for policy changes* — rather than as a request anyone logs. If the first design
partner's first ask is this, the right move is to reopen at once, not to defend the trigger.

## Alternatives considered

**Build now — the layered per-tenant Rego bundle.** ADR-0073's "likely shape of the eventual
answer," and refused for now: it decides signing, composition and versioning under zero usage
signal, and permanently widens the surface, on demand that has never been expressed by a customer.

**Build now — a constrained policy form the product compiles.** The best fit for the persona and
the most work — "a product in itself" per ADR-0073. Refused on the same demand absence, with
higher stakes: it is the option whose cost is hardest to recover if the premise is wrong.

**A request on-ramp — the tenant drafts a change in-product; it lands as a governance PR.** The
least irreversible option, and the first one to re-examine when the trigger fires. Refused only
for now: it still needs the decision ADR-0073 flagged as larger than it looks — how a tenant
enters a platform repository's review queue — and SPEC-0055 AC6/AC7 were built so that nothing on
the surface looks like authoring waiting to be unlocked.

**Withdraw PR-27, as PR-32 was withdrawn.** Refused. PR-32 was withdrawn because nobody could
start it from this repository; PR-27 can be started here, and the question is whether. Withdrawing
a requirement that is buildable but unwitnessed would abandon the wedge's premise without
evidence; deferral with a trigger is the honest middle.

## Follow-ups

- On acceptance: annotate the PRD's PR-27 row and §12.1 (decision 5).
- The reopened decision itself, if the trigger fires, starting from ADR-0073's narrowing rule.
- Give the trigger an observer: design-partner feedback is reviewed against decision 3, so demand
  arrives as a reopening rather than as churn.
