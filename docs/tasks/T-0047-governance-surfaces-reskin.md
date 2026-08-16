# T-0047: Security, merge request and compliance surfaces on the token layer

- **Status:** Todo — blocked-by T-0045
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

- [ ] AC7: the security dashboard and MR findings render on tokens; severity is encoded by glyph and
      label as well as colour; triage controls meet AA contrast in both themes.
- [ ] AC6 (on these surfaces): the merge-gate outcome, the finding severity and the evidence-pack
      status each carry a non-colour channel; a status added later with colour only fails the
      enumeration test.

## Tests to write first

- vitest: the status-vocabulary enumeration over these surfaces — every member has glyph and label.
- vitest: triage control contrast pairs, both themes.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.
