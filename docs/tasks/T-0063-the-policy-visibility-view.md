# T-0063: The policy visibility view

- **Status:** Done (2026-08-19) — webfrontend@c152501; SPEC-0055 AC4–AC10 proven
- **Phase / Epic:** 4 / EP-26 (Tier B)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0055-*.md (AC4–AC10)
- **ADRs:** 0072, 0073, 0070, 0069, 0006
- **Owner:** unassigned

## Goal

See the spec. This task is one repository's share of it, split along the ADR-0027 boundary.

## Acceptance criteria (test-first)

- [x] SPEC-0055 AC4–AC10 — as written in the spec; the spec is the authority and this file does not restate it.

## Tests to write first

- As the spec's *Acceptance criteria* section requires, RED before implementation.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- ADR-0072 defers job logs and ADR-0073 defers policy authoring. Neither absence is a gap to fill
  opportunistically here: both are decisions with their own follow-ups.

## Exit record (2026-08-19)

**AC4–AC10 green.** webfrontend **c152501**.

**The wording problem here is the sharpest in the phase.** Authoring is absent because ADR-0073
defers deciding what a tenant-authored policy *is* — not because the reader lacks a role. From the
outside those are indistinguishable, and every instinct of UI writing pushes toward the wrong one: a
greyed-out button, "contact your administrator", "coming soon". Each sends the reader to ask
somebody, and there is nobody to ask. The copy names where policy is authored and says outright that
nothing is waiting on a permission they lack; the enumeration refuses the alternatives; and nothing
on the page is disabled, because a greyed-out control says the opposite of all of it.

**Allowed against denied is not the success/danger pair**, and a denial takes the muted tone rather
than the danger one: deny-by-default means most denials are the system working, and colouring them
as failures would teach a compliance reader to skim past the normal case looking for red.

**A dry-run decision says it decided nothing.** Rendering it identically to an enforced one would
misrepresent what happened, which on this surface is the whole question.

**Carried (SPEC-0055 open question 2):** a reader sees that a revision decided their case without
seeing what that revision says. Bundle contents are a platform artifact, not a tenant read.
