# T-0028: Permission-filtered code search

- **Status:** Todo
- **Phase / Epic:** 2 / EP-14 Code search
- **Repo(s):** backend + bff
- **Spec:** docs/specs/SPEC-0034-permission-filtered-code-search.md; docs/specs/SPEC-0035-code-search-contract.md — both **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0014, 0006, 0025, 0022
- **Owner:** unassigned

## Goal
Code search returns results filtered by the caller's permissions, **never leaking the existence** of
unauthorized content (PR-19). ADR-0014 fixes a dedicated trigram/indexed engine (Zoekt-style), not
Postgres FTS, with incremental indexing off repo events.

## Acceptance criteria (test-first)
- [ ] AC1: substring, regex, and symbol queries return code-aware results across a tenant's
      accessible repositories.
- [ ] AC2: results are filtered to the caller's tenant and accessible repositories, enforced on
      **every result path** — result list, counts, facets, and any "more results" indicator.
- [ ] AC3: a query matching only unauthorized content is indistinguishable from a query matching
      nothing — no count, no timing-free hint, no error that reveals existence.
- [ ] AC4: indexing is incremental off repo events; a push is reflected within a stated
      **index-freshness bound**, and that bound is measured (ADR-0014 follow-up).
- [ ] AC5: a **reindex** of a repository is possible without downtime for other repositories, and a
      partially reindexed repository never serves stale results as authorized (ADR-0014 follow-up).
- [ ] AC6: **access-filter tests** exist as part of this task, not as a follow-up (ADR-0014
      follow-up) — permission revocation takes effect on the next query, not the next reindex.
- [ ] AC7: index size is reported against the fair-use **code-search index size** dimension (PRD §6).

## Tests to write first
- unit (backend): query parsing — substring, regex, symbol; tokenization of identifiers/camelCase.
- policy/isolation: authorized vs unauthorized repository; revoked permission mid-session; a query
  whose only matches are unauthorized returns exactly what a no-match query returns.
- integration: push → index → query within the freshness bound; reindex while serving.
- contract: search surface against `governance/contracts`; BFF aggregation only (invariant 18).

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Independent of T-0022…T-0027 and gates nothing; it can run alongside the findings plane from the
start. The stateful index is a separate subsystem to run and scale (ADR-0014 consequences) — under
ADR-0025 it stays a module until a measured fitness trigger justifies extraction (ADR-0026, ADR-0030,
T-0009). Correct at write time and stale at read time still leaks existence: AC2 and AC6 are the ones
to prove live, not against fakes. Cross-repo changes land governance-first under ADR-0027.
