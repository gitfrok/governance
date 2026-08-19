# SPEC-0035: Code search query and indexing contract

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Code Search, Repository/Git, Policy, Identity & Access
- **ADRs:** 0014, 0006, 0022, 0032
- **Task(s):** T-0028
- **PRD:** PR-19

## Problem / context

SPEC-0034 requires permission-filtered, non-enumerating code search with incremental indexing, and
leaves the boundary unspecified. Without a contract, the BFF would filter results, Code Search would
read Repository/Git storage to index, or a caller would supply the repository set to search — each of
which turns a leak into a schema property. This specification defines the additive boundary before
implementation.

## In scope

- An additive Code Search query surface with tenant-scoped, permission-derived results.
- The indexing intake: repository events consumed, and the indexing status surface.
- The reviewed action vocabulary this adds.

## Out of scope

- The findings, policy, evidence and merge-request surfaces (SPEC-0025…0032).
- Browser routes; the BFF aggregates and shapes only.
- Any caller-supplied repository set, permission claim, or authorization outcome.
- Search over non-code artifacts.

## Contracts touched

Additive `contracts/proto/search/v1/search.proto` with:

- `Search` and `GetIndexStatus`.
- Every request carries required context: tenant ID, verified actor ID, verified actor roles, request
  ID. A caller cannot assert them, and cross-tenant or empty context is a coarse denial.
- `Search` accepts a query string, a query mode (`SUBSTRING`, `REGEX`, `SYMBOL`), bounded result and
  context-line limits, and a signed, tenant-bound cursor. It does **not** accept a repository
  allow-list, a permission claim, an "include unauthorized" flag, or a scoring override. The
  searchable repository set is **server-derived** from the caller's permissions at query time.
- A result carries opaque repository and revision identifiers, path, line range, and bounded matched
  content. It carries no filesystem location, credential, blob handle, or permission fact.
- Result counts and any "more results" indicator are computed **under the caller's authorization**.
  The response has no field capable of expressing a total that includes unauthorized matches, so
  non-enumeration is a type property rather than a filter applied late.
- A query with no authorized matches and a query with no matches at all return the same status and
  the same response shape; the contract defines no error, code, or field that distinguishes them.
- `GetIndexStatus` reports per-repository index freshness — last indexed revision and lag — for
  repositories the caller may read, and reports nothing for others.
- Code Search consumes Repository/Git's existing ref-update events to drive incremental indexing and
  fetches content through Repository/Git's contract surface; it never reads Git storage or another
  context's tables (ADR-0022).

Additive events under `contracts/events/search/v1`: `RepositoryIndexed` and `IndexLagged`, carrying
opaque identifiers, tenant scope, revision and lag — never matched content or permission facts.

The policy follow-up adds this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `search.query` | `tenant` | query mode, derived repository scope |
| `search.read` | `repository` | revision, index freshness |
| `search.index.status.read` | `repository` | last indexed revision, lag |

Repository scope, freshness and lag are facts produced by Code Search and Identity & Access; none is
a caller claim.

## Data owned

Code Search owns the index, indexing state, cursors and its event payloads. Repository/Git owns
content and ref events; Identity & Access owns permissions; Policy owns authorization. Cross-context
facts arrive as opaque identifiers, contract calls, or event-fed projections.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A tenant-scoped principal runs substring, regex and symbol queries and pages results with
  a signed cursor; a forged, expired or cross-tenant cursor yields no content.
- [ ] AC2: The searchable repository set is server-derived; a request that carries a repository
  allow-list, permission claim or authorization flag is rejected, not partially honoured.
- [ ] AC3: Counts and "more results" indicators are authorization-derived, proven by differential
  tests against two principals over the same corpus.
- [ ] AC4: A query whose only matches are unauthorized returns a byte-identical response to a
  genuine no-match query, including status, shape and counts.
- [ ] AC5: A permission revocation binds on the **next query** — no reindex, cache cycle or cursor
  reuse serves the revoked content.
- [ ] AC6: `GetIndexStatus` reports freshness only for readable repositories and reveals nothing —
  not even existence — for others.
- [ ] AC7: Indexing is driven by consumed ref-update events and content fetched through the
  Repository/Git contract; boundary tests prove no Git storage or foreign table access.
- [ ] AC8: `buf lint` and `buf breaking` are green; all additions are additive within v1 and
  generated-code freshness is green at the composition boundary (ADR-0032, T-0020).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | queries, cursors, results, status and events are tenant-scoped |
| G2 least privilege | the repository set is server-derived; nothing about scope is caller-assertable |
| G4 change governance | additive-only within v1 and gated in CI |
| G9 least-privilege footprint | responses carry opaque identifiers and bounded matched content, never storage detail, credentials or permission facts |

## Non-functional

- Result and context-line limits are bounded by the contract; no query streams unbounded memory.
- Regex evaluation is bounded so a pathological pattern cannot monopolize the index or become a
  timing oracle.
- Response latency must not distinguish "no matches" from "unauthorized matches" observably.
- Denial and not-found errors do not distinguish nonexistent, cross-tenant and unauthorized
  repositories.

## Open questions / assumptions

- ~~**Package name.**~~ **Settled at approval (2026-08-14):** `contracts/proto/search/v1` and
  `contracts/events/search/v1`, alongside SPEC-0025's `security/v1` and SPEC-0032's `audit/v1`.
- **Cursor lifetime** is unset; it must be short enough that AC5's next-query revocation is not
  defeated by a long-lived cursor, which is the constraint rather than a specific value.
- **Assumption:** Repository/Git exposes a content-fetch path suitable for indexing. If it does not,
  adding one is part of T-0028 and lands governance-first under ADR-0027 — not a reason to read Git
  storage directly.
