# T-0045: Design token foundation, self-hosted fonts, and the app shell

- **Status:** Todo — **blocked-by ADR-0069 acceptance** (a Proposed ADR may not be built against)
- **Phase / Epic:** 3.5 / EP-24 (design system)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0047-cvd-first-design-system.md (AC1–AC4)
- **ADRs:** 0069, 0015, 0019
- **Owner:** unassigned

## Goal

Give the frontend something to render on. One token layer carrying both themes, fonts served from
our own origin, a visible focus ring on every interactive element, and a build gate that fails on a
hex literal in a component — so the drift that produced today's inline-hex state cannot recur.

The app shell (`src/layouts/Layout.astro`) is the first consumer and the proof: it currently holds
nine hardcoded colours and must hold none.

## Acceptance criteria (test-first)

- [ ] AC1: every token in SPEC-0047's *Binding tokens* table is defined in both Frost and
      Deepfreeze; a test asserts completeness against that table.
- [ ] AC2: the hex-literal check fails the build on a hex colour anywhere in `src/**` outside the
      token file, naming file and line. A deliberate violation is proven to fail.
- [ ] AC3: Inter, Baloo 2 and JetBrains Mono are served as WOFF2 from our origin with
      `font-display: swap`; no page requests `fonts.googleapis.com` or `fonts.gstatic.com`.
- [ ] AC4: every interactive element in the shell renders the 2 px `#0072B2` focus ring at 2 px
      offset in both themes; no rule removes an outline without replacing it.

## Tests to write first

- vitest: token-completeness against the spec table; focus-ring assertion on the shell's controls.
- The hex-literal gate itself, plus a fixture proving it fails on a violation.
- The no-CDN-font assertion over the built output.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Gates: `tsc --noEmit`, vitest (including the
unmodified `usage-regression-pins` and `readonly-cause`), `astro build`.

## Notes

The shell keeps its ADR-0049 auth affordance exactly as it behaves today — cookie presence is a
presentation hint, never a decision. This task changes how it looks, not what it knows.
