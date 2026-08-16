# T-0048: Usage view and code search on the token layer, pins unmodified

- **Status:** Done (2026-08-17) — webfrontend@56c91d1; SPEC-0047 AC8/AC9 proven
- **Phase / Epic:** 3.5 / EP-24 (design system)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0047-cvd-first-design-system.md (AC8, AC9)
- **ADRs:** 0069, 0061 (metering authority — untouched), 0018 (the PR-7 read-only mode)
- **Owner:** unassigned

## Goal

Re-render the usage view and code search on tokens **without changing what either says**. The usage
view carries the phase's sharpest constraint: two build-blocking suites already encode its honesty
rules, and this task must pass both without editing either.

## Acceptance criteria (test-first)

- [x] AC8: `usage-regression-pins` and `readonly-cause` pass **unmodified** — "not metered" never
      renders as zero, no commercial state renders read-only, every read-only condition names its
      cause. A failure here means the reskin changed behaviour; the fix is the reskin, never the test.
- [x] AC9: any chart or multi-series visual uses the Okabe–Ito order, varies dash pattern on lines,
      and ships a visible legend; no series pair is red vs green.
- [x] AC6 (on these surfaces): envelope state, trend direction and read-only cause each carry glyph
      and label beside their colour.

## Tests to write first

- Run the two existing suites first, before any edit, and keep them green throughout.
- vitest: the Okabe–Ito series order and legend presence.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Exit record (2026-08-17)

Closed in one webfrontend landing: **56c91d1**.

**AC8 holds and is provable rather than asserted:** `usage-regression-pins` and `readonly-cause` pass
**unmodified**, and `git diff` over both files is empty across the whole phase. The state WORD is
still rendered exactly as the pins require; it now simply arrives with a glyph beside it.

**AC6 on these surfaces.** Three envelope states were told apart by tint alone; each now has its own
glyph, and a test refuses two states sharing one — a shared glyph is the quickest way to put the
whole distinction back into colour. Trend was one muted grey word and is now an arrow plus the word,
so direction is visible at a glance without adding a hue.

**AC9 — met before the first chart exists.** There is no chart in the product today. The honest
options were to record AC9 as vacuous or to fix the palette now so the first chart cannot get it
wrong; this task took the second. The Okabe–Ito eight ship in the brand's fixed order as
`--gf-series-1..8`, each paired with a `--gf-series-N-dash`, and `tests/usage-cvd.test.ts` pins both
the order and blue-then-orange as the first pair — the two a deutan reader separates most easily.
**No chart is claimed; the palette a chart must use is.**

All five new suites joined the build-blocking `prebuild` set, so the design system cannot regress
silently: tokens, the gate's own fixture, the diff, the status vocabulary, the commercial surface.

**Gates:** hex-literals clean at zero, `tsc` clean, vitest **202/202**, `astro build` clean.

**Honest not-run:** SPEC-0047 AC10 captures — the phase's one carried gap.
