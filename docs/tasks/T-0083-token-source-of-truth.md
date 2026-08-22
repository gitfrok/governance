# T-0083: `tokens.json` becomes the source, and `tokens.css` becomes output

- **Status:** Done (2026-08-23) — AC1–AC7 proven; webfrontend 23a76d8, super-repo 390ffda
- **Phase / Epic:** design system (ADR-0091)
- **Repo(s):** governance, webfrontend, super-repo
- **Spec:** ../specs/SPEC-0066-token-source-of-truth.md (AC1–AC7)
- **ADRs:** 0091 (the kit is the source), 0032 (generated artifacts are gated), 0027 (one submodule
  per commit), 0047/0069 lineage via SPEC-0047

## What this task does

Authors `webfrontend/design/tokens.json` over all 87 governed tokens with light and dark values,
generates `webfrontend/src/styles/tokens.css` from it, and gates both — freshness against the source
and the CVD laws against the values. Moves the `./UI` comp in beside them without its blocked CDN
imports. Amends SPEC-0047 from holding the values to constraining them.

The safety property is AC1: because the kit holds no value the governed layer does not already hold
(SPEC-0066's measurement — 0 of 22 shared names differ, and all 18 kit-only real values are renames
of governed tokens), the generated CSS must come out identical to today's. Any difference is an
authoring defect, not a design change.

## Order of work

1. **governance** — SPEC-0066 Approved, this task filed, SPEC-0047 amended. *(this commit)*
2. **webfrontend** — RED first: the freshness check and the AC1 equivalence check, both failing
   because there is no `tokens.json`. Then author it, then the generator, until both pass. Then the
   CVD gate (AC3), the comp move with imports stripped (AC6), and the four addition candidates
   resolved (AC7).
3. **super-repo** — the freshness gate wired into `make verify`, and pins.

## Acceptance criteria

Tracked in SPEC-0066. Recorded here as they are proven, with the evidence.

- [x] **AC1** all three token scopes reproduce identically from `tokens.json` — `:root` 87/87,
      `[data-theme='deepfreeze']` 25/25, the `prefers-color-scheme` block 25/25, value for value.
      Plus a no-loss check: **0** substantive lines of the 590-line original are absent from the
      three files it became.
- [x] **AC2** 53 distinct names consumed, **0** unresolved against the generated layer. (The one
      apparent miss was `var(--gf-*)` inside a prose comment.)
- [x] **AC3** `scripts/check-token-cvd.mjs` fails when a status colour has no glyph — proven by
      adding `--gf-stale` and watching it fail, then removing it.
- [x] **AC4** `scripts/check-tokens-fresh.mjs` passes in step and fails naming both sides on a hand
      edit; wired into webfrontend's `prebuild`, `make tokens-check`, and CI beside `codegen-check`.
- [x] **AC5** hex-literal gate: `OK — every colour in src/ resolves from a token`. `components.css`
      took no exemption and needs none.
- [x] **AC6** 0 references to `fonts.googleapis.com` or `fonts.gstatic.com` under `design/` or
      `src/styles/`; the comp's three were stripped when it moved in.
- [x] **AC7** all four resolved as **renames, not additions**: `--gf-muted`, `--gf-slice`,
      `--gf-sh-sm` and `--gf-sh-md` already exist in the governed layer by those exact names — they
      were only ever "kit-only" relative to the mistaken 17-token count that ADR-0091's correction
      fixed. Nothing was added, so no new CVD verdict was owed.

## Notes

- The kit is untracked until step 2 lands, so SPEC-0066's mapping table is normative against the
  version measured 2026-08-23. Re-measure before starting if it has changed.
- `--gf-font-display` (`'Baloo 2'`) is deliberately out of scope: whether to vendor the WOFF2 or
  retire the token is a font-hosting decision, and AC6 only forbids the CDN reference.

## What went wrong, and what caught it

Two defects in the implementation, both found by something other than review:

1. **The first split silently dropped content.** Its boundary began at the
   `prefers-reduced-motion` block, but `.gf-code`, `.gf-sha` and the
   `:focus-visible` ring sit *between* the dark `@media` block and that one, so
   they vanished. AC1 could not see it — it compares token scopes, and these are
   not tokens. `tests/design-tokens.test.ts` failed on the missing focus ring.
   The boundary is now the end of the last token scope, and a no-loss check
   guards it.
2. **The round-trip dropped 19 trailing comments.** A single regex cannot tell a
   comment that opens a group from one annotating a declaration on the same line.
   The parser is line-based now; notes survive and are emitted only in the
   defining scope.

`tests/design-tokens.test.ts` was updated to read the three stylesheets as one
text, which is what it always was reading — otherwise the split would have
quietly narrowed its font and focus assertions to a file that no longer holds
them.

## Deliberate limit

AC3 gates CVD **law 2** (no hue-only encoding) and not law 1's "≥ 25 L\*". That
figure is the brand kit's, quoted in a `tokens.css` comment; SPEC-0047 states no
threshold and proves law 1 through AC10's grayscale and deuteranopia captures.
Enforcing a number governance does not state would be inventing governance in a
script, so law 1 stays where its evidence is. Recorded so the gap is a decision.
