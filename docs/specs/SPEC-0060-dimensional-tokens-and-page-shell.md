# SPEC-0060: One type scale, one page shell, and a gate that keeps geometry in the token layer

- **Status:** Implemented (2026-08-19) — AC1–AC10 green; webfrontend@45ffd61. 461 literals to zero, 0 waivers
- **Owner:** platform
- **Context(s):** Web frontend only. No contract, no policy, no backend port.
- **ADRs:** 0079 (decides this), 0069 (the design system this extends), 0015 (enforced, not
  aspirational), 0047's spec being amended in effect — see *Relationship to SPEC-0047*
- **Task(s):** T-0077 (webfrontend)

## Problem / context

ADR-0079 measured it: 347 dimensional literals across 32 files, 224 of them font sizes in ten
distinct sizes against a single type token, three different content widths, and 22 radius literals in
five radii while three radius tokens exist. The radius rows are already SPEC-0047 AC1 violations; the
spacing and type rows violated nothing, which was the finding.

This spec converts all of it in one task and adds the check that keeps it converted.

**What a reader actually sees today**, and the reason this is not only tidiness: page content is
1080 px wide on Pipelines, 960 px on a merge request and 760 px on Settings, so the column jumps as
they navigate. Cards render with 6 px, 8 px and 16 px corners depending on which task built them.
Secondary prose is 13 px in some places and 12 px in others.

## Relationship to SPEC-0047

SPEC-0047 is Implemented and stays so. Its AC1 named "every colour, radius, shadow, motion duration
and focus-ring value"; ADR-0079 decision 1 extends that sentence to spacing, size and type, and this
spec carries the extension. **SPEC-0047's ACs are not edited** — an Implemented spec's criteria are a
record of what was proven, and re-opening one to widen a rule would make that record unreliable. The
widened rule lives here, and AC1 below states it in full so no reader has to assemble it from two
documents.

## In scope

- A seven-step type scale in the token layer, and every font size in `src/` resolving from it.
- Every spacing, radius and size value in `src/` resolving from a token.
- One page shell owning content width, gutters and the page heading; every page composing it.
- A build-blocking gate over dimensional literals, with a reason-carrying waiver.

## Out of scope

- **Any visual redesign.** Colour, layout structure, information architecture and copy are untouched.
  The visible changes are the three type merges in AC2, plus the two the exit record names: Settings'
  column widening from 760 px to the one content width, and hand-rolled 6/8 px card corners becoming
  the 10 px control radius. Both are decisions 3 and 6 doing what they say.
- **The 12 px / 13 px collapse** (ADR-0079's named debt).
- **A component library.** A shell and a scale are not a design-system package.
- **Dark mode's GA question**, ADR-0069's open decision.
- **Any change to what a surface says or reads.** No BFF call changes.

## Acceptance criteria (each becomes a test)

- [x] **AC1 — one token layer, extended.** Every colour, radius, shadow, motion duration, focus-ring,
      **spacing, size and type** value in `src/` resolves from a single token definition. A test
      asserts the shipped stylesheet defines every token in ADR-0079's type table plus the existing
      `--gf-space-1…8` and `--gf-radius-*` sets.
- [x] **AC2 — the type scale is the seven steps ADR-0079 names**, and the three merges are the only
      size changes: 11→12, 15→16, 24→22. A test asserts each token's value, so a later "small tweak"
      to the scale is a visible diff against a governed table rather than a CSS edit.
- [x] **AC3 — no dimensional literal in the authored tree.** A check over `src/pages`,
      `src/components` and `src/layouts` fails on a `px`, `rem` or `em` value in a size, spacing,
      radius or type property, outside `src/styles/`. It names file and line, and runs in the same
      build-blocking position as the hex gate.
- [x] **AC4 — the gate can fail, and its fixture proves it.** A test drives the checker over a fixture
      carrying a `fontSize: '13px'` and asserts it is reported. A gate nobody has watched fail is a
      gate nobody knows the shape of.
- [x] **AC5 — the waiver states a reason, and the count is reported.** `gf-allow-dimension: <reason>`
      on the line exempts it; a bare marker does not. The gate prints how many waivers it passed over
      on every run — that number is the evidence for ADR-0079's follow-up about narrowing the rule, so
      it is visible rather than discoverable.
- [x] **AC6 — one content width.** A page shell component owns width, gutters and the heading. Every
      page in `src/pages` **that renders markup** composes it, and no page declares a `maxWidth`. Where
      a surface needs a different measure it asks for a named variant — never a number.
      **Amended during implementation, before Done:** the measures are `prose`, `wide` and **`full`**.
      The code surfaces — diff, tree, file — were full-bleed before the shell existed, and putting them
      in a column would have been the visual redesign ADR-0079 said it was not doing; they compose the
      shell with `full` so geometry still has one owner. And `raw/[revision]/[...path].astro` composes
      nothing, because it is a byte proxy that renders no `Layout` and therefore has no content column.
      The test excludes it by that property rather than by name.
- [x] **AC7 — the shell renders the heading once.** A test asserts a page composing the shell renders
      exactly one `h1`, and that the shell's landmark structure (`main`, skip link) is unchanged from
      what `Layout.astro` already provides. Two `h1`s is the failure a shell most easily introduces.
- [x] **AC8 — cards stop hand-rolling corners.** No component sets a radius outside the token set;
      `.gf-card` or a radius token carries it. This is the SPEC-0047 AC1 compliance half.
- [x] **AC9 — nothing about behaviour changed.** The full unit and e2e suites pass unmodified except
      where a selector names a value this spec moved; `usage-regression-pins` and `readonly-cause` are
      untouched; the hex gate still reports zero.
- [x] **AC10 — the captures are re-reviewed.** Every surface in the CVD capture set is regenerated and
      reviewed in grayscale and deuteranopia. The three size merges are what the review is looking
      for: a heading that got smaller, a badge that got bigger, and nothing else.

## Exit record (2026-08-19)

**AC1–AC10 green.** webfrontend **45ffd61**. 461 dimensional literals in the authored tree to **zero**,
with **0 waivers** — the number ADR-0079's follow-up asks about, and the answer on day one is that
nothing needed waiving. The two exclusions that would have been waivers are excluded by construction
instead: breakpoints, because `@media (min-width: 640px)` means where the layout changes rather than
how big a thing is, and border widths and underline offsets, because they are optical constants.

**Two corrections to ADR-0079's claim that "the three size merges are the entire visible change".**
The ADR is Accepted and immutable (ADR-0001), so the correction is recorded here:

1. **Settings was 760 px wide and is now 960 px.** Decision 3 says one content width; 760 was one of
   the three the decision collapsed. The ADR's summary sentence undercounted its own decision.
2. **Card corners were 6 px and 8 px in the components that hand-rolled them, and are now 10 px** — the
   control radius. That is decision 6's compliance half doing exactly what it said, and it is visible.

Both were found by the capture review, which is what the review is for. Nothing else moved.

**`ch` for form fields, and why it is not a way around the gate.** A number input for "days" is as wide
as its digits, not as wide as a scale step, so the age filters and facet columns take `ch` rather than
a spacing token — and stay correct if the type scale changes. The gate reads `px`, `rem` and `em`, so a
type size in `em` is still caught; `ch` on a width is the right unit for a content-relative measure.

**The waiver's reason is judged after the comment terminator is stripped.** Otherwise
`gf-allow-dimension: */` reads as a reason of `*/`, and the gate's one rule — say why — would be
satisfiable by punctuation. A bare marker exempts nothing and lands in the violation list at the line
where the missing reason belongs.

## Non-functional

- The gate is a text check over the authored tree, like the hex gate. It parses nothing and is not a
  linter plugin: a dependency added to enforce a house rule is a dependency the house then owns.

## Open questions / assumptions

1. **The waiver list is expected to be short — 1 px hairlines and the focus ring's 2 px offset.** If it
   grows past a handful, ADR-0079's follow-up says narrow the gate to type and content width. The
   count printed by AC5 is how that gets decided.
2. **`src/styles/` is exempt as a directory, not `tokens.css` as a file.** The stylesheet holds three
   hardcoded sizes today and will hold the scale tomorrow; exempting the directory keeps a second
   stylesheet from becoming a reason to weaken the gate.
3. **The shell does not replace `Layout.astro`.** Layout owns the document, the nav and the landmarks;
   the shell owns the content column inside it. Merging them would put nav geometry and page geometry
   in one component, and pages would start reaching into the nav.
