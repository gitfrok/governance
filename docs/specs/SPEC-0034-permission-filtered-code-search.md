# SPEC-0034: Permission-filtered code search

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Code Search, Repository/Git, Policy, Identity & Access
- **ADRs:** 0014, 0006, 0022, 0025, 0026, 0030
- **Task(s):** T-0028
- **PRD:** PR-19

## Problem / context

Code search over many large repositories is a specialized workload — identifier and camelCase
tokenization, symbol and regex queries — that general-purpose full-text search handles poorly
(ADR-0014). It is also the easiest place in the product to leak: a result count, a facet, or a
latency difference can reveal that content exists in a repository the caller may not read. ADR-0014
therefore requires enforcement **on every result path**, never obscurity.

## In scope

- Substring, regex and symbol queries with code-aware tokenization across a tenant's accessible
  repositories.
- Permission filtering of every result path — list, counts, facets, and any "more results" indicator.
- Non-enumeration: a query matching only unauthorized content is indistinguishable from a query
  matching nothing.
- Incremental indexing off repository events, with a stated and measured freshness bound.
- Reindex without cross-repository downtime.
- Index size reported against the fair-use dimension (PRD §6).

## Out of scope

- Findings, policy, evidence and merge-request surfaces (SPEC-0024…0033). Code search is independent
  of the findings plane and gates nothing in Phase 2.
- Cross-tenant or global search of any kind.
- Search over non-code artifacts — issues, merge-request text, wiki — which would be later specs.
- Extraction of Code Search into its own deployable service. Under ADR-0025 it stays a module until a
  measured fitness trigger fires (ADR-0026, ADR-0030, T-0009).

## Data owned

Code Search owns its index, its indexing state, and its freshness records. Repository/Git owns
repository content and emits the events that drive indexing; Identity & Access owns permissions,
which reach the query path as server-derived facts. Code Search reads no other context's tables
(ADR-0022) and never serves content it cannot attribute to an authorized repository.

## Acceptance criteria (each becomes a test)

- [ ] AC1: Substring, regex and symbol queries return code-aware results across a tenant's accessible
  repositories, with identifier and camelCase tokenization.
- [ ] AC2: Every result path is permission-filtered — result list, counts, facets and any "more
  results" indicator — enforced at query time from server-derived permission facts.
- [ ] AC3: A query whose only matches are unauthorized content returns **exactly** what a no-match
  query returns: same status, same body shape, same counts, no distinguishing error.
- [ ] AC4: Indexing is incremental off repository events; a push is searchable within a stated
  freshness bound, and that bound is **measured**, not asserted (ADR-0014 follow-up).
- [ ] AC5: A repository can be reindexed without downtime for other repositories, and a partially
  reindexed repository never serves stale content as authorized.
- [ ] AC6: **Access-filter tests exist within this task**, not as a follow-up (ADR-0014 follow-up):
  permission revocation takes effect on the **next query**, not the next reindex or cache cycle.
- [ ] AC7: Index size is reported per tenant against the fair-use **code-search index size** dimension
  (PRD §6); this spec records the measure and implements no metering.
- [ ] AC8: A query is tenant-scoped; a cross-tenant query, cursor or result is impossible, and failure
  is coarse (SPEC-0001).
- [ ] AC9: Boundary tests prove Code Search reads no other context's tables and that the BFF performs
  no filtering, ranking or authorization of its own (invariant 18).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | index, queries, cursors and events are tenant-scoped |
| G2 least privilege | permissions are enforced on every result path at query time; revocation binds on the next query |
| G5 auditability | index and query paths carry no bypass an audit could not explain |
| G9 least-privilege footprint | results expose authorized content only; existence is never inferable from counts, facets or errors |

## Non-functional

- Interactive latency for a bounded result page at Phase-2 scale; regex queries are bounded so a
  pathological pattern cannot monopolize the index.
- Freshness lag after a push is stated as a bound and measured against it; exceeding the bound is a
  reported condition, not a silent delay.
- Latency must not vary observably between "no matches" and "matches the caller may not read"
  (AC3's timing corollary).
- The index is a stateful subsystem with its own scaling and rebuild cost (ADR-0014 consequences);
  its resource profile is one of the measured extraction triggers under ADR-0030.

## Open questions / assumptions

- **Reindex strategy** — full rebuild versus shard-level repair — is an ADR-0014 follow-up left to
  implementation, constrained by AC5.
- **Freshness bound value** is unset; the spec requires a stated, measured bound rather than a
  particular number, which is an approval-time product decision.
- **Assumption:** permission facts are obtainable at query time cheaply enough to enforce per result
  path. If they are not, the resolution is a projection with a fail-closed staleness rule — never a
  post-filter over an unfiltered result set, and never an index that encodes permissions at write
  time only.
- **Recorded deployment-posture limit (Phase-2 code review M13, 2026-08-14).** The search index is
  in-process only: nothing of it survives a dataplane restart, and it rebuilds from backfill and
  re-announced repository events. **AC4**'s stated, measured freshness bound and **AC5**'s
  no-downtime reindex are therefore bounded by restarts under the single-tenant dev posture — a
  restart is a freshness-bound event and repositories go unserved-as-indexed until rebuilt, which is
  fail-closed for AC5 (unindexed content is not served as authorized). The index is bounded per
  repository (20 000 files × 1 MiB) but has **no per-tenant or global cap**, so AC7's fair-use
  dimension is measured but uncapped today. Follow-up: startup seeding or a persistent index, and
  per-tenant/global caps. Recorded alongside the phase exit verdict
  (`../plans/phase-2-ultimate-wedge.md`, note (e)); this records a limit, not a decision — no ADR.
