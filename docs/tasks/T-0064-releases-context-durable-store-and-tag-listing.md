# T-0064: Releases context, durable store, and tag listing

- **Status:** Todo
- **Phase / Epic:** 4 / EP-27 (Tier C — first increment)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0056-releases-tags-and-notes.md (AC1–AC7)
- **ADRs:** 0075, 0071, 0070, 0022, 0069, 0006
- **Owner:** unassigned

## Goal

One repository's share of SPEC-0056, split along the ADR-0027 boundary. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0056 AC1–AC7 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **No artifacts.** ADR-0075 accepted the tags-and-notes increment only; an artifact field, an
  upload route or a download link re-opens signing, custody, retention and metering at once.
- **The tag is a mutable pointer.** A release records the commit it pointed at when published, and
  the surface says when the two have diverged. That is the point of the record existing.
