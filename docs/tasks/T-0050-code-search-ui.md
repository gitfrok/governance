# T-0050: Code search in the web UI, with an honest empty state

- **Status:** Todo
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

- [ ] AC1: all three contract modes post as JSON; an unnamed mode refused before a request compiles.
- [ ] AC2: results render in the backend's order, none dropped, added or re-sorted.
- [ ] AC3: absent enrichment metadata changes nothing but the metadata.
- [ ] AC4: an empty page never says "no results" — the copy enumeration forbids "no results",
      "no matches", "nothing exists", "0 results", "not found" and any count of what was withheld.
- [ ] AC5: index freshness renders beside the empty state; three cases driven — fresh, stale, and an
      **empty entry list**, which reads as "nothing is indexed".
- [ ] AC6: a failed status read reads as "unknown", never as "nothing is indexed".
- [ ] AC7: no total, count or "of N" anywhere; the client type has no total to render.
- [ ] AC8: paging follows `next_page_token` verbatim; no offset or page number is computed.
- [ ] AC9: refusal names no cause.
- [ ] AC10: Search is reachable from the shell and backed by a route.
- [ ] AC11: tokens gate at zero; units on every length; the two pins unmodified with an empty diff.
- [ ] AC12: stub serves both routes with the three empty-state fixtures; captures regenerated and
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
