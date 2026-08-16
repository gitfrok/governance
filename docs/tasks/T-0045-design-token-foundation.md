# T-0045: Design token foundation, self-hosted fonts, and the app shell

- **Status:** Done (2026-08-17) — webfrontend@cdf032c; SPEC-0047 AC1–AC4 proven
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

- [x] AC1: every token in SPEC-0047's *Binding tokens* table is defined in both Frost and
      Deepfreeze; a test asserts completeness against that table.
- [x] AC2: the hex-literal check fails the build on a hex colour anywhere in `src/**` outside the
      token file, naming file and line. A deliberate violation is proven to fail.
- [x] AC3: Inter, Baloo 2 and JetBrains Mono are served as WOFF2 from our origin with
      `font-display: swap`; no page requests `fonts.googleapis.com` or `fonts.gstatic.com`.
- [x] AC4: every interactive element in the shell renders the 2 px `#0072B2` focus ring at 2 px
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

## Exit record (2026-08-17)

Closed in one webfrontend landing: **cdf032c**.

- **AC1** — `src/styles/tokens.css` carries every token in SPEC-0047's binding table in both Frost
  and Deepfreeze, plus shape, motion, focus and the status glyph vocabulary. The glyphs ship as
  content tokens (`--gf-glyph-*`) rather than characters typed into components, so ADR-0069's
  never-hue-only law holds by construction rather than by review. 60 assertions in
  `tests/design-tokens.test.ts`; a token missing from either theme fails.
- **AC2** — `scripts/check-hex-literals.mjs`, wired build-blocking in `prebuild`. It found **232
  literals across 16 files** on first run, which is the drift ADR-0069 describes. It ships as a
  **ratchet**: the 15 files T-0046…T-0048 still own are listed as LEGACY, no new file may join
  them, and a cleaned-but-still-listed file also fails. `tests/hex-literal-gate.test.ts` drives the
  real script over a fixture tree — clean tree passes, a violation fails naming file and line, an
  annotated `gf-allow-hex:` exemption passes, generated code is ignored.
- **AC3** — Inter, Baloo 2 and JetBrains Mono vendored as WOFF2 under `public/fonts`, served from
  our own origin with `font-display: swap`. All three are variable faces, so one file per family
  covers every weight (110 KB total). Verified against the **built output**: zero references to
  `fonts.googleapis.com` or `fonts.gstatic.com` in `dist/`.
- **AC4** — one `:focus-visible` rule, 2 px `--gf-action` at 2 px offset, both themes. A test
  refuses any `outline: none` not immediately replaced in the same rule.

The shell (`src/layouts/Layout.astro`) is the first consumer and holds no literals. Nav marks the
current destination with `aria-current` **and** weight **and** an inset rule — never colour alone —
and a skip link is the first control in the tab order. Only destinations with a BFF surface appear.
The ADR-0049 auth affordance is untouched: cookie presence stays a presentation hint.

**Gates:** `tsc --noEmit` clean (adds `@types/node`; the new tests read files), vitest **155/155**
with `usage-regression-pins` and `readonly-cause` **unmodified**, `astro build` clean.

**Honest not-run:** SPEC-0047 AC10's grayscale and deuteranopia captures are per-surface and belong
to the tasks that own those surfaces; the shell alone was reviewed by reading the token
definitions, not by screenshot. No capture is claimed here.
