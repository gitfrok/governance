# T-0055: The repository landing page, replacing the T-0001 stub

- **Status:** Done (2026-08-18) — webfrontend@39e224b; SPEC-0052 AC10–AC13 proven
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0052-repository-registry-and-list.md (AC10–AC13)
- **ADRs:** 0071, 0070, 0069, 0015
- **Owner:** unassigned

## Goal

`src/pages/index.astro` has been the T-0001 scaffolding stub since Phase 0, because no route could
answer what belongs on it. Now one can.

## Acceptance criteria (test-first)

- [x] AC10: the landing page lists the caller's repositories, each linking to its tree.
- [x] AC11: an empty list never claims the tenant has none — the copy enumeration, as SPEC-0049 AC4
      governs the empty search page.
- [x] AC12: no total or count; a refusal names no cause; tokens at zero, units on every length, the
      two regression pins unmodified.
- [x] AC13: stub serves populated, empty and refusing cases; captures regenerated and reviewed.

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

## Exit record (2026-08-18)

**AC10–AC13 green.** webfrontend **39e224b**. `index.astro` has been the T-0001 scaffolding stub for
the whole project; it stayed one because no route could answer what belongs on it.

**AC11's enumeration caught its own copy on the first run.** The unavailable message read *"this is
not a statement that there are none"* — true, and it failed the check on its own negation. The copy
was rewritten rather than the check weakened: a blunt substring check is what survives someone
shortening the copy in a year, and a check with negation-aware exceptions is not.

A refusal renders as its own third state, distinct from the empty list, because *we could not ask*
is not *nothing is visible to you*. No count appears anywhere: the contract carries no total, so any
figure would be invented, and on this surface an invented figure is a claim about what was withheld.

Captures reviewed empty and populated, grayscale and deuteranopia.
