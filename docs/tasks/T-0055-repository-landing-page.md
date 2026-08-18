# T-0055: The repository landing page, replacing the T-0001 stub

- **Status:** Todo
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0052-repository-registry-and-list.md (AC10–AC13)
- **ADRs:** 0071, 0070, 0069, 0015
- **Owner:** unassigned

## Goal

`src/pages/index.astro` has been the T-0001 scaffolding stub since Phase 0, because no route could
answer what belongs on it. Now one can.

## Acceptance criteria (test-first)

- [ ] AC10: the landing page lists the caller's repositories, each linking to its tree.
- [ ] AC11: an empty list never claims the tenant has none — the copy enumeration, as SPEC-0049 AC4
      governs the empty search page.
- [ ] AC12: no total or count; a refusal names no cause; tokens at zero, units on every length, the
      two regression pins unmodified.
- [ ] AC13: stub serves populated, empty and refusing cases; captures regenerated and reviewed.

## Tests to write first

- vitest: the client — no scope field travels; a refusal is one coarse failure.
- vitest: the copy enumeration over every string this surface can render.
- vitest: the empty-list rendering, asserted as distinct from the refusal rendering.
- playwright: landing → repository tree, plus the empty and refusing journeys.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Notes / open questions

- The empty list is the same class of claim as the empty search page: it must not assert absence.
- Harness limit: do not assert page content directly after a form submit — see T-0050's exit record.
