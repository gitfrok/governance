# ADR-0070: The prototype's six absent surfaces become product, gated by a route-before-pixel law

- **Status:** Proposed
- **Date:** 2026-08-18
- **Deciders:** platform (requested by the product owner: "implement all UI/UX with all features we
  have", 2026-08-18)
- **Supersedes / superseded by:** supersedes SPEC-0047's *Out of scope* record for the six
  prototype surfaces, and the super-repo `HANDOFF.md` carried limit 19 that restates it. Neither is
  wrong; both are scope records made under a narrower mandate, and this ADR is the spec that limit
  19 says such a restoration requires.
- **Related:** ADR-0015 (GitHub-clean UX principles — unchanged and still binding), ADR-0069 (the
  CVD-first design system every new surface must ride), ADR-0019 (Astro + React SSR), ADR-0022
  (bounded contexts), ADR-0027 (repository topology — one commit never spans two submodules),
  ADR-0049 (BFF browser session), ADR-0006 (deny-by-default PDP)
- **Governs:** PR-8 (browsing, its blame/history half), PR-9 (MR review loop, its write half),
  PR-11 (pipelines), PR-16 (policy authoring), and the new requirements §*New PRD requirements*
  below proposes

## Context

Three inventories describe the web surface, and they disagree.

**What the BFF serves** is eighteen routes. Ten of them have a UI. Eight do not: merge-request
create, review and merge; code search query and status; evidence-pack request, status and fetch;
and auditor-grant issue, list and revoke.

**What the PRD requires** is twenty-three `PR-#` rows. Several name behaviour no surface renders:
PR-8 names blame and history, PR-9 names open/comment/approve/merge, PR-16 names policy authoring,
PR-19 names code search, PR-17 and PR-18 name the compliance surfaces.

**What the `./UI` prototype shows** is a larger product still: a dashboard, an issues tracker,
releases, a pipelines list, repository settings, an admin area, an audit-log browser, a runners
view, an activity feed and a marketing landing page.

SPEC-0047 recorded six of those as out of scope, correctly, because its mandate was *re-skin, not
new features* and because a prototype is not a requirement. `HANDOFF.md` limit 19 restates it and
adds the escape clause: **"do not 'restore' them without a spec."** This ADR exists to be that
decision, and the specs it authorises are enumerated below.

The gap that makes this urgent is not the prototype. It is that **a merge request can be read in
the product but not acted on.** The BFF has served create, review and merge since T-0016; the web
UI has never called them. PR-9 — a team can open, review, comment on, approve, and merge a merge
request — is the core forge loop, and half of it exists only as an HTTP route no human can reach.

## Decision

**1. The six absent prototype surfaces are adopted as product scope.** Issues, Releases, the
pipelines list, repository Settings, the Admin area and the marketing landing page stop being
"prototype only". Each becomes a numbered PRD requirement, an epic and a spec, or it does not get
built — adoption is not a licence to render a screen from the prototype's HTML.

**2. Route before pixel — the ordering law.** No UI surface may be built before the BFF route it
reads exists, and no BFF route may be built before the backend port it shapes exists. The
dependency direction is already one-way (`webfrontend → bff → backend → governance`, invariant 22);
this makes the *build order* follow it too. The concrete consequence: a surface whose backend does
not exist is not "UI work blocked on backend" — it is backend work that has not started, and it is
tasked that way.

The law's test is mechanical. For every destination in the app shell's navigation there must be a
BFF route that returns its data. A destination with no route is dead nav, and dead nav is the
specific failure SPEC-0047 refused to ship.

**3. Nothing renders off the design system.** Every surface this ADR authorises rides ADR-0069's
token layer: no hex literal survives `check-hex-literals.mjs`, no status is encoded by hue alone,
every new status word enters `src/lib/status.ts` and is caught by the enumeration test the day it is
written, and each surface is reviewed in grayscale and deuteranopia per SPEC-0047 AC10. This ADR
widens *what* is built; it relaxes nothing about *how*.

**4. Three tiers, and only one of them may start now.**

- **Tier A — the route exists, the UI does not.** Merge-request actions, code search, evidence
  packs, auditor grants. These need a spec and a task, not a decision: the PRD already requires
  them and the BFF already serves them. Tier A work is `webfrontend`-only and may begin the moment
  its spec is Approved. It does not wait on this ADR's acceptance.
- **Tier B — the PRD requires it, no route serves it.** Repository list, blame, history, policy
  authoring, pipelines. Each needs backend and BFF work first, under the ordering law.
- **Tier C — the prototype shows it, nothing requires it.** Issues, Releases, Settings, Admin area,
  audit-log browser, runners, activity feed, marketing page. Each needs a PRD requirement before
  anything else, because there is currently no statement anywhere in governance that the product
  should have them.

**5. Tier C's PRD requirements are proposed, not assumed.** This ADR proposes the rows below. Until
it is Accepted and the PRD amended, no Tier C spec is written and no Tier C code is committed.

## New PRD requirements this ADR proposes

| Proposed | Requirement | Tier |
|---|---|---|
| PR-24 | A developer can list the repositories they may see, and only those; a repository they may not see is not distinguishable from one that does not exist | B |
| PR-25 | A developer can read a file's blame and a ref's commit history in the web UI | B |
| PR-26 | A developer can see pipeline runs and job logs for a repository, scoped by the same permissions as the repository read | B |
| PR-27 | A policy owner can author, version, dry-run and enforce a policy from the web UI, with the deciding version recorded (the UI half of PR-16) | B |
| PR-28 | A team can open, assign, label, discuss and close issues, and link them to merge requests | C |
| PR-29 | A team can cut and publish a release from a tag, with its artifacts and notes | C |
| PR-30 | A repository owner can read and change repository settings — name, description, visibility, members and archival — each change audited | C |
| PR-31 | An org administrator can read the org's members, roles, runners and audit log from an admin area, without gaining repository read access | C |
| PR-32 | An unauthenticated visitor is served a marketing landing page that never leaks tenant existence or content | C |

## Consequences

**Good.** PR-9's write half becomes reachable, which is the difference between a demo and a forge.
The route-before-pixel law makes the "why is this screen empty" class of bug impossible to author.
Every new surface inherits a design system that is already enforced by a build gate, so the cost of
being CVD-correct is near zero for work that starts now and would be high for work that started
before T-0045.

**Bad.** This is a large program — four Tier B surfaces and five Tier C ones, each needing backend,
BFF and web work in three separate commits under ADR-0027. Adopting Tier C also adopts its
maintenance: an issues tracker is not a screen, it is a bounded context with its own storage,
events, permissions and audit obligations.

**The risk this ADR is most likely to be wrong about.** Tier C is adopted from a prototype rather
than from a customer requirement. PR-28 through PR-32 are written as requirements, but their
evidence is a mockup, not a user. If they are built and unused, the cost is not the build — it is
that every one of them widens the audit, permission and residency surface permanently. The
mitigation is the ordering law plus the tiering: Tier C cannot start until its PRD rows are
Accepted, which is the point at which someone must defend them on their merits rather than on the
prototype's existence.

## Alternatives considered

**Build the prototype's screens directly.** Fastest to a demo, and the reason it is refused: the
prototype has no backend behind two thirds of its screens, so the result is nav that leads to
nothing — the exact failure SPEC-0047 avoided by leaving Issues, Releases, Settings and Admin out
of the shell rather than shipping them disabled.

**Tier A only; leave the prototype alone.** The narrow reading of "all features we have", and
defensible: it ships every feature that actually exists behind a UI, with no new bounded contexts.
Refused because the product owner's request was explicit after the tiering was put to them.

**Amend SPEC-0047.** Rejected on process grounds: SPEC-0047 is Approved and its scope record is a
statement about a phase that closed. A phase's scope is not retroactively widened; a new decision
supersedes it.

## Follow-ups

- Amend the PRD with PR-24…PR-32 once this ADR is Accepted; until then the rows above are proposals
  and the PRD is unchanged.
- A Proposed ADR per Tier C bounded context (issues, releases, settings, admin) — each is a context
  under ADR-0022, and none can be a screen bolted onto an existing one.
- Decide whether the marketing landing page belongs in `webfrontend` at all, or in a separate
  surface that never holds a session cookie.
