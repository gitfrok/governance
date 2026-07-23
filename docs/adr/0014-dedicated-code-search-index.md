# ADR-0014: Dedicated code-search index (Zoekt-style), not Postgres FTS

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G1 isolation, G2 least privilege, product quality

## Context
Code search over many large repos is a specialized workload: identifier/camelCase
tokenization, symbol and regex search, and scale that general-purpose full-text search
handles poorly. Results must also respect tenant isolation and per-repo permissions.

## Decision
Run a dedicated code-search subsystem built on a trigram/indexed engine (Zoekt-style)
that indexes repo contents and serves fast substring/regex/symbol queries. Search is
**permission-aware**: results are filtered to the caller's tenant and accessible repos
(never rely on obscurity). Indexing is incremental off repo events.

## Consequences
**Positive:** fast, code-aware search; regex/symbol support; scales independently.
**Negative:** a separate stateful subsystem to run/scale; index freshness lag after pushes;
must enforce access on every result path.
**Follow-ups:** index-freshness SLO; reindex strategy; access-filter tests.

## Alternatives considered
- **Postgres full-text search** — poor at code tokenization/regex; won't scale for this.
- **On-demand grep** — simple but does not scale to large repos/fleets.
