# T-0065: The release contract and BFF routes

- **Status:** Done (2026-08-19) — governance@a213d28, bff@9a76f1b; SPEC-0056 AC8–AC10 proven
- **Phase / Epic:** 4 / EP-27 (Tier C — first increment)
- **Repo(s):** governance, bff
- **Spec:** ../specs/SPEC-0056-releases-tags-and-notes.md (AC8–AC10)
- **ADRs:** 0075, 0071, 0070, 0022, 0069, 0006
- **Owner:** unassigned

## Goal

One repository's share of SPEC-0056, split along the ADR-0027 boundary. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0056 AC8–AC10 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **No artifacts.** ADR-0075 accepted the tags-and-notes increment only; an artifact field, an
  upload route or a download link re-opens signing, custody, retention and metering at once.
- **The tag is a mutable pointer.** A release records the commit it pointed at when published, and
  the surface says when the two have diverged. That is the point of the record existing.
