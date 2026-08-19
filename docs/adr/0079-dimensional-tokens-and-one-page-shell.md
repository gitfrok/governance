# ADR-0079: Spacing and type join the token layer, and one shell owns page geometry

- **Status:** Proposed
- **Date:** 2026-08-19
- **Deciders:** platform
- **Related:** ADR-0069 (the design system, and the colour-token law this extends), ADR-0015
  ("GitHub-clean" as an information-architecture principle; enforced, not aspirational), ADR-0070
  (the surfaces this now applies to), SPEC-0047 (the design-system spec and its AC1/AC2 gates)
- **Governs:** the `webfrontend` design layer. No PRD requirement — this is about how the surfaces
  the product already has hold together.

## Context

ADR-0069 decision 2 says **"tokens are the only source of colour"**, and it is enforced: the
hex-literal gate has held since T-0045 and reports zero. SPEC-0047 AC1 extends the same rule to
radius, shadow, motion duration and focus ring.

**Spacing and type were never covered, and they drifted.** Measured across `webfrontend/src` today,
after Phase 4 added ten surfaces:

| What | Count | The problem |
|---|---|---|
| Dimensional literals in pages, components and layouts | **347** across 32 files | Geometry is declared per file rather than resolved from anywhere |
| `fontSize` literals | **224**, in **10 distinct sizes** (11–24 px) | There is exactly **one** type token, `--gf-text-base: 14px`. There is no type scale, so every surface invented its own |
| The two workhorse sizes | 13 px (103 uses), 12 px (51 uses) | They differ by one pixel and mean the same thing — secondary prose. This is drift, not intent |
| `borderRadius` literals | 22, in **5 distinct radii** (4, 6, 8, 10, 999) | Three radius tokens exist. `--gf-radius-card: 16px` has **two** users while components hand-roll 6 px and 8 px card corners |
| Content width | **3 values** — 1080 px, 960 px, 760 px | Pages disagree about how wide the product is, and a reader moving between them sees the column jump |
| `tokens.css` itself | 3 hardcoded font sizes | Even the token file does not use a scale it does not have |

The radius rows are **already violations of SPEC-0047 AC1** — that AC binds radius, and nothing
caught it because the gate reads hex colours only. The spacing and type rows are not violations of
anything, which is the actual finding: *the product's most-repeated visual decision has no owner.*

**Why this matters more after Phase 4 than before it.** With four surfaces it is possible to keep
geometry consistent by looking. With seventeen pages built over three waves by different tasks, "it
looked right in the diff" stops being a mechanism. ADR-0015 called this out in advance —
"enforced, not aspirational" — and ADR-0069 made that true for colour and stopped there.

## Decision

**1. Spacing and type are token-resolved, on the same terms colour already is.** SPEC-0047 AC1's
sentence extends from "every colour, radius, shadow, motion duration and focus-ring value" to include
**every spacing, size and type value**. The existing `--gf-space-1…8` scale (4/8/12/16/24/32) stands
unchanged; a type scale is defined, because there is not one to stand on.

**2. The type scale is seven steps, chosen from what the product already renders**, so this is a
consolidation and not a redesign:

| Token | Value | Absorbs | Where it is used |
|---|---|---|---|
| `--gf-text-xs` | 12 px | 11 px | badges, table meta, timestamps |
| `--gf-text-sm` | 13 px | — | secondary prose, table cells (the 103-use workhorse) |
| `--gf-text-base` | 14 px | — | body copy; unchanged |
| `--gf-text-md` | 16 px | 15 px | section headings (`h2`) |
| `--gf-text-lg` | 18 px | — | card titles |
| `--gf-text-xl` | 20 px | — | page titles on dense surfaces |
| `--gf-text-2xl` | 22 px | 24 px | page titles |

Three near-duplicate merges — 11→12, 15→16, 24→22 — each at most two pixels. **Nothing else changes
size.** 13 px and 12 px both survive: they are one pixel apart and that is ugly, but collapsing them
would restyle 154 call sites, which is a redesign wearing a refactor's clothing and belongs to
whoever owns the visual language, not to this ADR.

**3. One shell owns page geometry.** Content width, gutters and the page heading are declared once, in
a shell component every page composes. A page states what it *is* — a title and its content — and
not how wide the product is. The three current widths collapse to one; if a surface genuinely needs a
different measure (a wide table, a narrow form), the shell takes a named variant rather than the page
taking a number.

**4. A gate enforces it, in the same build-blocking position as the hex gate.** A check over
`src/pages`, `src/components` and `src/layouts` fails on a dimensional literal — `px`, `rem`, `em`
in a size, spacing, radius or type property — outside the token definition file. It names file and
line, exactly as the hex gate does.

**5. The gate has a waiver, and the waiver must state a reason.** `/* gf-allow-dimension: <why> */`,
mirroring the hex gate's existing `gf-allow-hex`. A heuristic with no escape hatch gets deleted the
first time it misfires, and a deleted gate protects nothing — an audited exception is strictly better
than an unenforced rule. The 1 px hairline borders and the focus ring's 2 px offset are the expected
first waivers: both are optical constants, not scale steps.

**6. The radius drift is a compliance fix, not part of this decision.** Components stop hand-rolling
card corners and use `.gf-card`, or the radius tokens directly. That was already SPEC-0047 AC1's
requirement and needed no ADR — it is named here only because it is the same pass.

## What this does not decide

- **No visual redesign.** No colour, no layout structure, no information architecture. The three size
  merges above are the entire visible change, and they are reviewed as captures.
- **No new surface, and no change to what any surface says.** Every deferral Tier C recorded stays
  deferred; every gate stays.
- **Not whether Deepfreeze ships at GA.** ADR-0069's open decision, untouched.
- **Not the 12/13 px collapse.** Named as debt above, deliberately left.
- **Not a component library.** A shell and a token scale are not a design-system package, and
  proposing one here would be scope no measurement supports.

## Consequences

**Good.** The product's geometry becomes a property of the token layer rather than of whoever wrote a
page most recently. A reader moving between surfaces stops seeing the column jump. And the next
surface — whatever the next ADR admits — inherits geometry instead of inventing it, which is the same
economics the hex gate already produces for colour.

**Bad.** It touches 32 files at once, which is the diff shape reviewers trust least, and it lands on
top of Phase 4's ten new surfaces rather than under them. Nothing about it is user-visible except the
three merges, so the whole change is justified by consistency and by the gate that keeps it — which
is exactly the kind of work that gets deprioritised until it is too large to do.

**The risk this ADR is most likely to be wrong about.** That a dimensional-literal gate is worth its
false positives. The hex gate works because a colour outside the palette is *always* a defect; a
number outside the scale sometimes is not — a sprite offset, an optical nudge, a third-party embed's
required width. If the waiver list grows past a handful, the gate is measuring the wrong thing and
should be narrowed to type and content width, the two places drift actually hurt a reader. That
outcome is a follow-up, not a failure, and the waiver reasons are the evidence for it.

## Alternatives considered

**Tokenize, no gate.** Cheaper and it would work for a week. The 347 literals accumulated *while*
tokens existed and were partly used — the token layer is not the mechanism, the check is. Refused for
the reason ADR-0015 gives: aspirational is what this was.

**Gate type and content width only, leave spacing.** Genuinely defensible, and it is where decision 4
should retreat to if the risk above holds. Not chosen first because spacing literals are how the
padding of a card ends up different from the padding of the card beside it, and that is visible even
when no single value looks wrong.

**A full component library — Card, PageHeader, Table, Field as governed components.** Bigger, better,
and not supported by anything measured here. The measurement says the product has a geometry problem,
not a component-inventory problem. It would also make every future surface depend on a library nobody
has staffed.

**Do nothing, and re-measure after the next phase.** Honest option: none of this is user-facing except
three merges. Refused because the count is the argument — 347 literals is what "we will tidy it later"
produced over three waves, and later is now more expensive than it was.

## Follow-ups

- The 12 px / 13 px collapse, which needs someone who owns the visual language.
- Whether the gate should narrow to type and content width, decided from the waiver reasons after one
  phase of use.
- Whether `tokens.css`'s own three hardcoded sizes mean the stylesheet should be generated from the
  token table rather than hand-maintained.
