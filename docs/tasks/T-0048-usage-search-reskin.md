# T-0048: Usage view and code search on the token layer, pins unmodified

- **Status:** Todo — blocked-by T-0045
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

- [ ] AC8: `usage-regression-pins` and `readonly-cause` pass **unmodified** — "not metered" never
      renders as zero, no commercial state renders read-only, every read-only condition names its
      cause. A failure here means the reskin changed behaviour; the fix is the reskin, never the test.
- [ ] AC9: any chart or multi-series visual uses the Okabe–Ito order, varies dash pattern on lines,
      and ships a visible legend; no series pair is red vs green.
- [ ] AC6 (on these surfaces): envelope state, trend direction and read-only cause each carry glyph
      and label beside their colour.

## Tests to write first

- Run the two existing suites first, before any edit, and keep them green throughout.
- vitest: the Okabe–Ito series order and legend presence.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.
