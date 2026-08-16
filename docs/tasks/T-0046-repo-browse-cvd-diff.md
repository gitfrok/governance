# T-0046: Repo browsing and the CVD-safe diff

- **Status:** Done (2026-08-17) — webfrontend@089c514; SPEC-0047 AC5 proven, AC6 on these surfaces
- **Phase / Epic:** 3.5 / EP-24 (design system)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0047-cvd-first-design-system.md (AC5, AC6)
- **ADRs:** 0069, 0015
- **Owner:** unassigned

## Goal

Re-render the tree, file, raw and diff surfaces on the token layer, and re-encode the diff the way
ADR-0069 decides: added lines blue-tinted, removed lines orange-tinted, and a `+` or `−` in the
gutter of every changed line as text.

This is the flagship case for the whole phase. The diff is the most-read screen in a forge and it
currently ships the red/green encoding the brand kit exists to reject.

## Acceptance criteria (test-first)

- [x] AC5: added lines use `gf.diff.add.bg`, removed lines `gf.diff.del.bg`, and every changed line
      carries its gutter marker in the DOM as text — asserted independently of any colour, so the
      diff reads with colour rendering off.
- [x] AC6 (on these surfaces): no status renders by colour alone; each carries glyph and label.

## Tests to write first

- vitest: gutter markers present on every changed line, asserted with no reference to colour.
- vitest: the add/del backgrounds resolve from tokens, not literals.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Grayscale and deuteranopia captures for tree,
file and diff, recorded in the exit record (SPEC-0047 AC10).

## Exit record (2026-08-17)

Closed in one webfrontend landing: **089c514**.

`src/lib/diff.ts` parses a unified patch into typed lines; `src/components/DiffView.astro` renders
**four channels**, of which colour is the weakest: a text marker in the gutter, old/new line numbers
that stop in the column the change did not touch, an accessible name (`"added line"` / `"removed
line"`), and the blue/orange tint — the only channel a colourblind or grayscale reader loses.

The removed-line marker is **U+2212 MINUS**, not the patch format's U+002D hyphen: it matches the
plus in width and optical centre, so the pair separates by shape rather than by scanning.

`tests/diff-cvd.test.ts` (11 assertions) strips every tag before checking the markers and asserts the
rendered output contains **no hex literal at all**. One test exists solely to hold the parser's
ordering rule: `+++`/`---` file headers are classified as meta BEFORE the add/del test, which is how
a diff renderer avoids claiming a file header was added.

Tree, file and raw also moved to tokens. Each page dropped its own `<main>` — the shell provides one
and the pages were nesting a second, costing a screen-reader user their landmark. Entry kinds read as
words (`dir`, `symlink`), never as a colour. `RepoHeader.astro` ends the per-page re-improvisation
that let these four drift apart.

**Gates:** hex-literals OK (ratchet 15 → 11), `tsc` clean, vitest **166/166** with the two pins
unmodified, `astro build` clean.

**Honest not-run:** SPEC-0047 AC10 captures — see the phase plan's carried gap.
