# T-0050: Code search in the web UI, with an honest empty state

- **Status:** Done (2026-08-18) — webfrontend@a668de5; SPEC-0049 AC1–AC12 proven
- **Phase / Epic:** 4 / EP-25 (Tier A — the routes that exist and have no UI)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0049-code-search-surface.md (AC1–AC12)
- **ADRs:** 0070, 0069, 0014, 0015, 0006
- **Owner:** unassigned

## Goal

The last Tier A item. PR-19 has been served since T-0028 and called by nothing; `CommandPalette.tsx`
is navigation and has never issued a query. The work is small in surface and sharp in one place: what
an empty result page is allowed to say.

## Acceptance criteria (test-first)

- [x] AC1: all three contract modes post as JSON; an unnamed mode refused before a request compiles.
- [x] AC2: results render in the backend's order, none dropped, added or re-sorted.
- [x] AC3: absent enrichment metadata changes nothing but the metadata.
- [x] AC4: an empty page never says "no results" — the copy enumeration forbids "no results",
      "no matches", "nothing exists", "0 results", "not found" and any count of what was withheld.
- [x] AC5: index freshness renders beside the empty state; three cases driven — fresh, stale, and an
      **empty entry list**, which reads as "nothing is indexed".
- [x] AC6: a failed status read reads as "unknown", never as "nothing is indexed".
- [x] AC7: no total, count or "of N" anywhere; the client type has no total to render.
- [x] AC8: paging follows `next_page_token` verbatim; no offset or page number is computed.
- [x] AC9: refusal names no cause.
- [x] AC10: Search is reachable from the shell and backed by a route.
- [x] AC11: tokens gate at zero; units on every length; the two pins unmodified with an empty diff.
- [x] AC12: stub serves both routes with the three empty-state fixtures; captures regenerated and
      reviewed.

## Tests to write first

- vitest: the query client — mode validation before a request is compiled; the page token sent
  verbatim.
- vitest: the copy enumeration over every string this surface can render.
- vitest: the three index-freshness readings, and the refused-status reading as distinct from them.
- vitest: result order preserved against the response.
- playwright: query → results → next page, and each of the three empty states.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Notes / open questions

- **`Page` has no total, by design.** SPEC-0035 AC3 makes non-enumeration a type property: there is
  no field capable of expressing how many matches the caller may not see. Anything the UI renders as
  a count would be invented.
- **The empty page is the same shape for "nothing matched" and "every match was unauthorized"**
  (SPEC-0035 AC4). "No results found" asserts non-existence and is therefore the leak PR-19 forbids,
  inverted.
- **The index is in-process and lost on restart** (carried limit 12). After a restart every query
  returns an empty page, which is a third meaning for the same shape. The status route is the only
  thing that separates them, and an EMPTY status list is the signal — not an error.

## Exit record (2026-08-18)

**All twelve criteria green. Tier A is complete** — every BFF route that had no UI now has one.
Closed in one webfrontend landing: **a668de5**.

**What now exists.** `src/lib/search.ts` (the copy table, `readIndexFreshness`, `STALE_AFTER_MS`),
`src/components/SearchResults.astro`, `src/pages/search/index.astro`, the SSR query relay, and a
**Search** destination in the shell. Tests: `search-bff`, `search-render`, `search-route`, all three
in the build-gating `prebuild` list, plus `e2e/search.spec.ts`.

**The trap was the empty page, and it has three meanings sharing one shape.** A query that matched
nothing, a query whose every match the caller may not see, and a query against an index that holds
nothing all return the same empty `SearchPage` with no total — `SearchPage` has no field capable of
carrying one, because SPEC-0035 AC3 makes non-enumeration a type property. The copy therefore says
what is true of all three: *this query returned nothing you can see*, explicitly distinguished from
*nothing exists*. "No results found" would assert non-existence, and on an unauthorized query that
is PR-19's leak inverted — telling a reader nothing is there when something is.

The index status is what narrows it, and its empty answer is a **signal rather than an error**:
`readIndexFreshness(null)` is `unknown` and `readIndexFreshness({entries: []})` is `nothing-indexed`,
kept apart because "we could not ask" and "the index is empty" are different facts. Freshness reports
the **worst** lag across repositories; reporting the best would overstate how current the index is,
which is the direction that misleads.

**Two defects surfaced that this task did not cause.**

- **Every page nested a `<main>` inside the shell's `<main>`** — two `main` landmarks and invalid
  HTML on every rendered page, present in seven pages since the Phase 3.5 shell landed. Fixed across
  all of them in this commit.
- **The e2e journeys asserted less than they appeared to.** The session travels as a request header,
  because Chromium accepts a `__Host-` cookie only over https, and Playwright does not apply those
  headers when the browser follows the 303 that every form POST answers with — so the redirected
  page rendered signed-out and read nothing from the BFF. Every assertion about post-submit *content*
  was passing against a signed-out page. The submit now proves the redirect and a `goto` of the
  resulting URL proves what that URL renders; the grant journey additionally asserts the
  server-bounded expiry is **present**, which an empty page would previously have satisfied
  vacuously. This is a harness limit, recorded here rather than fixed away: it is why these journeys
  re-navigate.

**Carried:** query text travels verbatim including a regex — the backend owns evaluation and its own
bounds. There is no scope selector, because a query has no repository field and one would imply the
caller can narrow server-derived scope. The staleness threshold is a display threshold only; the lag
is rendered beside the word so a reader who disagrees with it can see the number.
