# SPEC-0026: Unified security dashboard & triage

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Security/Findings (ADR-0022); Policy and Audit as provider/sink
- **ADRs:** 0015, 0006, 0007, 0022
- **Task(s):** T-0023; T-0024, T-0026 (consumers)
- **PRD:** PR-14

## Problem / context

SPEC-0024 normalizes findings and fixes their identity; nothing yet lets a human act on them. ADR-0015
makes the unified surface a design rule: security, vulnerability and compliance data consolidate into
one place rather than scattering into per-scanner tabs. A security lead needs every finding for a
repository and for an org in one view, narrowed by the dimensions they actually triage along, and a
decision they record must still be there after the next scan.

Triage is a **control action**, not a UI preference. Accepting a risk is a claim an auditor may later
read (PR-17), so it is authorized, audited, and attached to a finding identity rather than to a scan.

## In scope

- One dashboard listing findings for a repository and for an org, across every scanner class.
- Filtering by **severity, class, age, and owning team**, in combination.
- **Triage state** — `ACCEPT`, `FALSE_POSITIVE`, `FIX`, `DEFER` — as a resource of its own, attached
  to a finding identity, surviving re-scan by construction.
- PDP authorization and immutable audit of every triage transition.
- Permission filtering of every result path: list, counts, filter facets, and pagination.
- Owning-team attribution as an input to filtering.

## Out of scope

- The findings model and identity rule (SPEC-0024) and the ingestion boundary (SPEC-0025).
- Placement of a finding on a merge request (SPEC-0028) — the dashboard does not own MR context.
- Any policy that *gates* a merge on a triage state (SPEC-0029/0030). Triage records a human decision;
  it grants no authorization outcome.
- Evidence-pack rendering of triage decisions (SPEC-0031).
- Bulk triage, saved views, notification/subscription, and SLA timers. If wanted, each is a later
  additive spec.

## Contracts touched

Additive triage and dashboard-read surface, specified in **SPEC-0027**. Triage is a separate resource
keyed by finding identity; SPEC-0025 states triage is not representable in the finding message, and
this spec does not change that.

## Data owned

Security/Findings owns triage records, their history, and the owning-team attribution it derives.
Policy owns authorization; Audit owns immutable records. Team membership originates in Identity &
Access and reaches this context as opaque identifiers or an event-fed projection — never by reading
another context's tables (ADR-0022).

## Acceptance criteria (each becomes a test)

- [ ] AC1: One dashboard lists findings for a single repository and across an org, spanning every
  scanner class ingested under SPEC-0025.
- [ ] AC2: Results are filterable by severity, class, age, and owning team, in combination, and the
  same filter yields the same set on repeat.
- [ ] AC3: A finding is triaged as `ACCEPT`, `FALSE_POSITIVE`, `FIX`, or `DEFER`, and the state
  **survives a re-scan** — proven by ingesting a later scan and asserting the state is still attached
  to the same finding identity.
- [ ] AC4: A triage transition is authorized by the PDP with server-derived context and appends
  exactly one immutable audit record naming the actor, the finding, the prior and new state, and the
  decision ID (ADR-0006, ADR-0007).
- [ ] AC5: Triage history is retained: superseding a decision does not mutate or erase the prior one.
- [ ] AC6: A caller sees findings only for repositories they may read. No count, aggregate, filter
  facet, or "more results" indicator changes because of a finding on a repository they may not read.
- [ ] AC7: A finding resolved by a later scan (SPEC-0024 AC9) still carries its triage history and is
  distinguishable in the dashboard from one never seen.
- [ ] AC8: The BFF aggregates and shapes only; triage rules, filter semantics, and authorization live
  in the backend (ADR-0020, invariant 18) — proven by a boundary test.
- [ ] AC9: The surface meets ADR-0015's interaction bar — one consolidated view with progressive
  disclosure and keyboard-reachable filters, not a per-scanner tab set.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | every list, count, facet and triage record is tenant-scoped |
| G2 least privilege | triage is a PDP decision; permission filtering applies to every result path |
| G3 supply chain | one consolidated view across all scanner classes, per ADR-0015 |
| G5 auditability | every triage transition is immutable, actor-named and decision-correlated; history is retained |
| G6 compliance | an accepted risk remains attached to the finding across scans, so it still means something at audit time |

## Non-functional

- Interactive latency for a filtered list at Phase-2 scale; pagination is bounded and cursor-based.
- Triage transitions are serializable per finding and idempotent per actor, finding and request ID.
- Aggregate counts are computed under the caller's authorization, never from an unfiltered
  pre-aggregate.

## Open questions / assumptions

- **Owning-team attribution source.** Whether a team owns a repository, a path, or a finding class is
  undecided; v1 assumes repository-level ownership fed from Identity & Access. A path-level model is
  an amendment, not a filter tweak.
- **`DEFER` semantics.** Whether a deferral carries an expiry that returns the finding to untriaged is
  an approval-time decision; the ACs above assume a deferral persists until superseded.
- **Assumption:** triage is per finding identity, not per occurrence. If a tenant needs per-branch
  triage, that is a different resource and a later spec.
