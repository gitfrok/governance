# SPEC-0049: Code search — query, page, and say honestly what an empty page means

- **Status:** Implemented (2026-08-18) — every acceptance criterion is proven by its task(s); approved (2026-08-18) — no new decision is required; PR-19 already binds, SPEC-0034 and
  SPEC-0035 already fix the behaviour, and the BFF has served both routes since T-0028. ADR-0070
  Tier A.
- **Owner:** platform
- **Context(s):** Web frontend (renders) · BFF (shapes, forwards and enriches) — ADR-0022. No backend
  or contract change.
- **ADRs:** 0070, 0069, 0014 (code search), 0015, 0019, 0049, 0006
- **Task(s):** T-0050

## Problem / context

PR-19 requires that code search returns results filtered by the caller's permissions, **never
leaking existence of unauthorized content**. The BFF has served the surface since T-0028:

| Route | Shape | Returns |
|---|---|---|
| `POST /api/v1/search/query` | JSON `{query, mode, result_limit, context_line_limit, page_token}` | `SearchPageView` |
| `GET /api/v1/search/status` | — | `IndexStatusPageView` |

Nothing in the frontend has ever called either. `CommandPalette.tsx` is often mistaken for search —
it is navigation: its three commands change the browser route for the current repository, and it
holds no query, no results and no upstream call.

**The trap here is what an empty result page means, and it is the most consequential empty state in
the product.**

`Page` carries results and a page token and **no total**. SPEC-0035 AC3 makes that a type property
rather than a convention: there is no field capable of expressing how many matches exist, precisely
so the surface cannot leak the count of matches the caller may not see. SPEC-0035 AC4 goes further —
the empty page is deliberately the **identical shape** for a query that matched nothing and a query
whose every match was unauthorized. The BFF cannot tell them apart. Neither can this layer.

So the natural copy — *"No results found"* — is a claim the frontend cannot support. It asserts
non-existence, which is exactly the leak PR-19 forbids, inverted: it tells an unauthorized caller
that nothing exists where something does.

**The second trap compounds the first.** The code-search index is in-process and does not survive a
data-plane restart (super-repo `HANDOFF.md` carried limit 12, recorded against SPEC-0034 AC4/AC5).
After a restart the index knows nothing, and a query against it returns — an empty page. Identical
shape again. `GET /api/v1/search/status` is what distinguishes them: it reports per-repository
freshness, and **an empty status list means nothing is indexed**, which is a different fact from
"your query matched nothing" and a different fact again from "you may not see what matched".

## In scope

- Running a query in each mode the contract names, with paging.
- Rendering matches with their repository, revision, path, line span and matched content, plus the
  file metadata the BFF enriched them with when it could.
- The empty-state honesty rules above, and the index-freshness reading that supports them.
- A search destination reachable from the app shell.

## Out of scope

- Any new BFF route, backend RPC or contract change.
- A result count, a total, a "showing 1–10 of N", or any rendering of how much was not returned.
  There is no field for it and its absence is the requirement.
- Ranking, re-ordering, client-side filtering or highlighting beyond the span the backend returned.
  Order and membership are the backend's (invariant 18).
- Searching within one repository as a scoped mode. The contract has no repository field on a query;
  scope is derived server-side, and a scope selector would imply otherwise.

## Contracts touched

None. `search/v1` and the BFF's `SearchPageView` / `IndexStatusPageView` JSON are consumed unchanged.

## Data owned

None.

## Acceptance criteria (each becomes a test)

- [x] **AC1** A query runs in each of the three modes the contract names — `SUBSTRING`, `REGEX`,
      `SYMBOL` — posted as JSON. A mode the contract does not name is refused before a request is
      compiled; the BFF's `ModeOf` refuses it too, as the coarse 404 that names nothing.
- [x] **AC2** Results render with repository, revision, path, line span and matched content, in the
      order the backend returned them. A test asserts the rendered order matches the response order
      and that no result is dropped, added or re-sorted.
- [x] **AC3** Enriched file metadata renders when present and its absence changes nothing else. A
      test drives a result with `metadata` absent and asserts the result still renders — enrichment
      failure degrades to no metadata, never to no result (the BFF's own contract).
- [x] **AC4** **An empty page never says "no results".** The copy states what is true of both
      possibilities — that this query returned nothing the caller can see — and does not assert that
      nothing matched, that nothing exists, or that anything was withheld. A test enumerates the
      copy: no rendered string on this surface may contain "no results", "no matches", "nothing
      exists", "0 results", "not found", or any count of what was not returned.
- [x] **AC5** **The index's freshness is shown beside the empty state, not instead of it.** When a
      query returns nothing, the page renders what the status route says about the index. A test
      drives three cases and asserts three different renderings: entries present and fresh; entries
      present but stale; and **an empty entry list**, which reads as "nothing is indexed" rather
      than as freshness data the reader can act on.
- [x] **AC6** **A failed status read never becomes an index claim.** If the status route refuses, the
      page says the index state is unknown. A test asserts it does not fall back to "nothing is
      indexed", which is a different fact and would be an invention.
- [x] **AC7** No total, count or coverage figure is rendered anywhere on this surface. A test asserts
      the rendered output contains no "of N" construction and that the client type carries no total
      field to render.
- [x] **AC8** Paging follows `next_page_token` only. A test asserts the next request carries the
      token verbatim and that the page never computes an offset, page number or "page 2 of".
- [x] **AC9** A refusal names no cause — SPEC-0048 AC4's copy enumeration applies verbatim.
- [x] **AC10** Search is reachable from the app shell, marked current by `aria-current` plus weight
      plus a rule, and backed by a BFF route.
- [x] **AC11** No hex literal is introduced; `npm run check:tokens` stays at zero; every style value
      carrying a length ships its unit; `usage-regression-pins` and `readonly-cause` pass
      **unmodified** with `git diff` over both empty.
- [x] **AC12** The e2e stub BFF serves both routes, including an **empty page with a populated index
      status**, an **empty page with an empty index status**, and a **status route that refuses**, so
      AC4, AC5 and AC6 are exercised end to end. Capture fixtures are write-free. CVD captures
      regenerated per SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | AC4 and AC7 are the rendering half of non-enumeration. The type carries no total; the copy asserts no absence. Together they mean the surface cannot leak what it was never told. |
| G2 authorization | The searchable set is derived server-side at query time. This layer sends no repository list and cannot narrow or widen scope. |
| G3 unified security | Search is the read path across the estate; an honest empty state is what keeps it from becoming an oracle. |

## Non-functional

- Server-rendered. The query is a form POST to an SSR relay, as every other write on this frontend
  is, so the browser holds no BFF address and search works with no client script.

## Open questions / assumptions

1. **Query text is sent verbatim, including in `REGEX` mode.** The backend owns evaluation and its
   own resource bounds; validating or rewriting a pattern here would be this layer deciding what a
   query means.
2. **There is no scope selector**, because a query has no repository field. Scope is server-derived
   and a selector would imply the caller can narrow it.
3. **Freshness is per repository and the page shows the worst of them.** A single summary is a
   judgement; showing the worst lag is the reading least likely to overstate how current the index is.
