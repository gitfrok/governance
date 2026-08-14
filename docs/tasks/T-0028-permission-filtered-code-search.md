# T-0028: Permission-filtered code search

- **Status:** Done (2026-08-14) — contracts governance@011eb2a; backend@267eaa4 (merged into the stack tip at 6b66da4 for the single super-repo pin); bff@4b93d25; AC4 recorded as a host limit against T-0003's cluster lane
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
- [x] AC1: substring, regex, and symbol queries return code-aware results across a tenant's
      accessible repositories.
- [x] AC2: results are filtered to the caller's tenant and accessible repositories, enforced on
      **every result path** — result list, counts, facets, and any "more results" indicator.
- [x] AC3: a query matching only unauthorized content is indistinguishable from a query matching
      nothing — no count, no timing-free hint, no error that reveals existence.
- [ ] AC4: indexing is incremental off repo events; a push is reflected within a stated
      **index-freshness bound**, and that bound is measured (ADR-0014 follow-up). *(host limit — see exit record)*
- [x] AC5: a **reindex** of a repository is possible without downtime for other repositories, and a
      partially reindexed repository never serves stale results as authorized (ADR-0014 follow-up).
- [x] AC6: **access-filter tests** exist as part of this task, not as a follow-up (ADR-0014
      follow-up) — permission revocation takes effect on the next query, not the next reindex.
- [x] AC7: index size is reported against the fair-use **code-search index size** dimension (PRD §6).

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

## Exit record (2026-08-14)
Phase-2 exit (task #23, 2026-08-14):
- AC1–AC3, AC5–AC7 green at the backend pin: the independent `feat/t-0028-codesearch-index` branch
  (267eaa4) was merged into the findings-plane stack tip (merge commit 6b66da4) so the super-repo's
  single backend pointer carries both lanes; the full backend suite (including the codesearch
  differential leak tests — a query whose only matches are unauthorized is indistinguishable from a
  no-match query — and the revocation-binds-on-next-query access-filter tests) re-ran green on the
  merge target, plus go build and go vet.
- BFF aggregation surface (4b93d25) green in the bff full suite at the bff pin.
- AC4 (measured index-freshness bound) is recorded as a **host limit** against T-0003's cluster
  lane: the push → index → query freshness measurement needs the dev cluster's event pipeline live
  end to end, and cluster bring-up on this host is infrastructure-bound (Phase-1 recorded the same
  shape). The incremental indexing path itself is tested; only the measured bound is deferred.
- Engine note: **Zoekt was evaluated and rejected** for this plane — ~110 transitive module
  requirements via `sourcegraph/zoekt` (language detection, roaring bitmaps, Prometheus, opentracing,
  a wasm RE2 runtime, a cloud gRPC stack), `google/zoekt` is an empty stub, its builder is disk-bound
  while this module's shards live in-process and swap atomically, and it offers no ctags-free SYMBOL
  mode — in favor of the in-module trigram engine behind the same ContentSource/engine port, so a
  later Zoekt swap is an engine change, not a module change (rationale recorded at
  `backend/modules/codesearch/internal/engine/engine.go`).
- Super-repo pointer lands with the phase-exit pin bump.

Fix wave 2 (review L15/L17, backend@42ad9b3): indexing jobs carry a per-job timeout so one hung
fetch no longer stops indexing for the whole plane (L15), and search cursors are bound to the
issuing actor (L17). See `../plans/phase-2-ultimate-wedge.md`.
