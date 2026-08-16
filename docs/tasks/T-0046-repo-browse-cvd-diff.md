# T-0046: Repo browsing and the CVD-safe diff

- **Status:** Todo — blocked-by T-0045 (nothing to render on until the tokens land)
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

- [ ] AC5: added lines use `gf.diff.add.bg`, removed lines `gf.diff.del.bg`, and every changed line
      carries its gutter marker in the DOM as text — asserted independently of any colour, so the
      diff reads with colour rendering off.
- [ ] AC6 (on these surfaces): no status renders by colour alone; each carries glyph and label.

## Tests to write first

- vitest: gutter markers present on every changed line, asserted with no reference to colour.
- vitest: the add/del backgrounds resolve from tokens, not literals.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Grayscale and deuteranopia captures for tree,
file and diff, recorded in the exit record (SPEC-0047 AC10).
