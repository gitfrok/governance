# T-0061: The pipeline runs view

- **Status:** Done (2026-08-19) — webfrontend@044cc59; SPEC-0054 AC10–AC14 proven
- **Phase / Epic:** 4 / EP-26 (Tier B)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0054-*.md (AC10–AC14)
- **ADRs:** 0072, 0073, 0070, 0069, 0006
- **Owner:** unassigned

## Goal

See the spec. This task is one repository's share of it, split along the ADR-0027 boundary.

## Acceptance criteria (test-first)

- [x] SPEC-0054 AC10–AC14 — as written in the spec; the spec is the authority and this file does not restate it.

## Tests to write first

- As the spec's *Acceptance criteria* section requires, RED before implementation.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- ADR-0072 defers job logs and ADR-0073 defers policy authoring. Neither absence is a gap to fill
  opportunistically here: both are decisions with their own follow-ups.

## Exit record (2026-08-19)

**AC10–AC14 green.** webfrontend **044cc59**.

**The capture review found its fourth defect of the phase, and this one was an inconsistency in the
work rather than a bug.** Queued and Cancelled sat on the same muted tone AND shared the hollow
circle, so in the one column a reader scans they were separable by the word alone. The grant list
already held the stronger rule — states rendered side by side get pairwise-distinct shapes — and
this now matches it. Cancelled takes ⊘, which reads as *stopped* where ✕ would have implied
*failed*. The test asserts pairwise distinctness across all five states rather than merely that each
has a glyph.

**The absence of logs is stated above the table**, once, where a reader looking for them will be.
No "coming soon", no disabled control, no link that 404s: each converts a decision nobody has taken
into a promise somebody made.

`RUNNING_JOB` and `FAILED_JOB` carry their suffix because `RUNNING` and `FAILED` already belong to
the scan and evidence-pack vocabularies. One key meaning two things in two contexts is how a badge
quietly renders the wrong word.
