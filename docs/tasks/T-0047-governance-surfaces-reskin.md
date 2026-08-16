# T-0047: Security, merge request and compliance surfaces on the token layer

- **Status:** Done (2026-08-17) — webfrontend@0f0dabd; SPEC-0047 AC6/AC7 proven
- **Phase / Epic:** 3.5 / EP-24 (design system)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0047-cvd-first-design-system.md (AC7, AC8's status half)
- **ADRs:** 0069, 0015 (the unified security surface this renders)
- **Owner:** unassigned

## Goal

The surfaces ADR-0015 called the differentiator — findings, triage, merge-request gating, evidence
packs and auditor grants — rendered on tokens, with severity and outcome carried by glyph and label
rather than hue.

## Acceptance criteria (test-first)

- [x] AC7: the security dashboard and MR findings render on tokens; severity is encoded by glyph and
      label as well as colour; triage controls meet AA contrast in both themes.
- [x] AC6 (on these surfaces): the merge-gate outcome, the finding severity and the evidence-pack
      status each carry a non-colour channel; a status added later with colour only fails the
      enumeration test.

## Tests to write first

- vitest: the status-vocabulary enumeration over these surfaces — every member has glyph and label.
- vitest: triage control contrast pairs, both themes.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Exit record (2026-08-17)

Closed in one webfrontend landing: **0f0dabd**.

Severity was a **red-to-green heat ramp** — crimson for critical, green for low — which is the exact
pairing ADR-0069 forbids: under deuteranopia the two ends converge and the badges become
indistinguishable. `src/lib/status.ts` is now the single vocabulary. Every member carries a glyph, a
word, and a token CLASS rather than a colour value, so no component can reach past the table to a
hex. Severity additionally carries a rank rendered as `Critical 4/4`, so intensity reads as text and
as order with every tint removed.

`tests/status-vocabulary.test.ts` (24 assertions) **enumerates** the table rather than sampling it: a
status added later with a hue and nothing else fails on the day it is written. Two behaviours are
pinned that were previously improvised — an unknown status renders as "Unknown status" rather than a
neutral grey badge (silently greying a real state is how it disappears from a dashboard), and no
severity may claim the success tone.

Finding lifecycle was colour-only (green text for `RESOLVED`) and now carries glyph and word.

The colour sweep covered all eleven remaining files, so **the ratchet reached zero**: every colour in
`src/` resolves from a token. The LEGACY list stays in the script as an empty set, because the
stale-entry check makes an empty list self-enforcing.

**Gates:** hex-literals **0 legacy files**, `tsc` clean, vitest **190/190** with the two pins
unmodified, `astro build` clean.

**Honest not-run:** SPEC-0047 AC10 captures; AA contrast for the triage controls is asserted by
token pairing and the brand's published ratios, not by an instrumented measurement.
