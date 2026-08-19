# T-0076: External issues on the merge request, and a link a reader can see the end of

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0059-external-issue-references.md (AC14–AC19)
- **ADRs:** 0074, 0069, 0070
- **Owner:** unassigned

## Goal

The browser half of SPEC-0059, on the existing merge request page. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0059 AC14–AC19 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **The host is shown, not hidden.** A reference is a link out of the product, and a reader should be
  able to see where it goes before clicking.
- **Merging closes nothing.** That is the first assumption a reader makes, so the page says it rather
  than letting the absence be discovered.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
