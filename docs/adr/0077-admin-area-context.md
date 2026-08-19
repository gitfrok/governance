# ADR-0077: The admin area is where privilege accumulates, and the audit log is not a page

- **Status:** Accepted
- **Date:** 2026-08-19 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform (required by ADR-0070's follow-up before any PR-31 spec)
- **Related:** ADR-0070, ADR-0007 (append-only audit), ADR-0029, ADR-0006, ADR-0049, ADR-0009/0010
  (residency), SPEC-0033 (auditor grants), ADR-0022, ADR-0071
- **Governs:** PR-31

## Context

The prototype shows an Admin area with Members, Roles, Runners, Audit log and `Last active`. PR-31
asks that an org administrator can read the org's members, roles, runners and audit log **without
gaining repository read access**.

That last clause is the whole requirement, and it is already a solved problem in this product for a
different reader. **PR-18 and SPEC-0033 built scoped, time-boxed auditor grants** precisely so that
someone can see evidence without seeing repositories — issued, listed and revoked, with every
lifecycle action audited. An admin area that reads the audit log is asking for the same separation
by a different name.

Two of the four panels carry their own problem.

**The audit log.** It is append-only and tamper-evident (ADR-0007) and it is the substrate the
evidence pack is assembled from. A browser over it is not a table view: it is an evidence surface
with none of SPEC-0033's scoping. Unbounded audit access for an "administrator" role would make the
auditor-grant machinery decorative — anyone who can be made an admin can read everything a grant was
designed to bound.

**Runners.** In BYO deployments the runners are in the customer's own cluster (ADR-0009, ADR-0010,
ADR-0065). Rendering their state means the control plane reporting on data-plane internals, and the
data plane's connection is outbound-only by design. What an admin sees is at best what the plane
last reported, which is a freshness claim exactly like the code-search index's — and carried limit 12
is the standing reminder of how that reads when it goes stale.

## Decision

**This ADR does not adopt the admin area. It fixes three boundaries.**

**1. The audit log is reached through a grant, not through a role.** Whatever an admin area shows of
the audit trail, it is bounded by SPEC-0033's grant model — scoped, time-boxed, revocable, and
itself audited. An `admin` role that reads the whole trail unbounded is a second, weaker access path
to the product's most sensitive store, and the existence of the first one is what makes the second
indefensible.

**2. "Admin" is not a new authorization primitive.** Roles today are tenant-level and PDP-decided
(ADR-0006, ADR-0049). An admin area asks the PDP the same way every other surface does; it does not
acquire a bypass, and it does not introduce a role that means "allowed everywhere".

**3. Runner state is rendered as a report with its own age, never as live truth.** The data plane is
outbound-only. A panel that implies otherwise misrepresents the architecture, and the honest
rendering names when the plane last said so — the same shape SPEC-0049's index-freshness reading
takes.

## Accepted scope (2026-08-19)

**The owner accepted this ADR with the two panels that can be built honestly today: a dated fleet
report, and a door into the grant flow.** That is the first increment, specified as SPEC-0058. The
three decisions above are what bounds it, and scoping it answered a question the ADR left open —
*what the four panels actually have behind them.*

**Members is deferred, because nothing can answer it.** Roles are tenant-level and come from Zitadel
(ADR-0049), and the Identity context has no member-listing port: it authenticates, it issues and
revokes auditor grants, and that is all. A members panel therefore needs either an outbound read
against the identity provider — its own decision, with its own failure mode when the provider is
unreachable — or a projection nobody has built. Under ADR-0070's route-before-pixel law that is not a
UI question yet. The panel is **absent rather than present-and-empty**, following ADR-0076 decision
2's shape: an empty table would say this org has no members, which is false.

**Roles is deferred with it, and for a related reason.** Without members, a roles panel is a table of
three definitions — which is documentation, and belongs where the policy bundle is, not in a surface
that implies it is reporting this org's state.

**The audit answer is composition, not a new surface.** PR-31's clause is "read the org's … audit log
**without gaining repository read access**", and that is exactly what SPEC-0033's scoped, time-boxed,
revocable auditor grants already do — issued, listed, revoked, each act audited, with the evidence
pack as the read surface. So the admin area **links into the existing grant and evidence flow** and
contains no trail browser. Decision 1 is satisfied by there being nothing else to satisfy it with.

**Decision 2 gets a mechanical gate.** The role vocabulary lives in `policies/gitsaas/authz` and a
rego test now pins `role_actions` to exactly `owner`, `member` and `reader`. An `admin` role that
means "allowed everywhere" cannot arrive as a convenience — it fails a test in the repository that is
the Source of Truth. This is decision 2's equivalent of ADR-0076's check 16, in the place where this
decision is actually expressible.

**Decision 3 is the fleet panel, and it is the interesting half.** The Agent context already derives
what this needs — `Fleet` returns each data plane with its status and the instant it was last seen,
and its own comment says *stale reads stale, never healthy*. The panel renders that instant, and says
plainly that the control plane reports what the plane last told it. It also says what it cannot show:
the CI runners inside a customer's own cluster are not visible from here, because the data plane's
connection is outbound-only and no surface should imply otherwise.

**`Last active` on a member is refused, not deferred.** This ADR's own follow-up asked whether it is a
fact this product should retain; the answer taken here is no. It is presence telemetry about people,
nothing else in the product collects any, and a field that exists gets used. The copy enumeration on
the view forbids it, so it cannot arrive as a column somebody thought was helpful.

**What this increment must not grow into without returning here:** a trail browser reached by a role,
an `admin` entry in `role_actions`, a live runner console, or per-person activity. The first two are
the reason this ADR exists; the third misrepresents the architecture; the fourth is surveillance the
product has so far declined to build.

## Consequences

**Good.** The auditor-grant model stays the single path to evidence rather than becoming the
inconvenient path. The outbound-only property survives contact with a status panel.

**Bad.** PR-31 is not delivered, and an admin area constrained this way is noticeably less than the
prototype shows — no unbounded log browser, no live runner console.

**The risk this ADR is most likely to be wrong about.** That grant-scoped audit access is workable
for an org administrator's actual job. An admin investigating an incident at 2am does not want to
issue themselves a grant, and if the honest answer is that they will simply be given a permanent
one, then the grant model has been preserved in form and lost in substance. If that is where this
lands, it is better to admit the admin role reads the trail and design *that* properly — with its
own audit record for every read — than to route it through a grant nobody treats as a boundary.

## Alternatives considered

**An admin role with unbounded audit read.** Refused as written, but the risk section above is the
argument for revisiting it — with per-read auditing, which the grant model gets for free and a role
does not.

**No audit panel at all; point administrators at the evidence pack.** Coherent, and the smallest
honest version: the pack already answers "what happened in this window" with provenance the
platform stands behind.

## Follow-ups

- Whether an org administrator's real workflow survives grant-scoped audit access.
- Runner reporting freshness, if a runners panel proceeds.
- Whether `Last active` on a member is a fact this product should retain at all — it is presence
  telemetry about people, and nothing else in the product collects that.
