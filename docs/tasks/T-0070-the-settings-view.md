# T-0070: The settings view, and an absence that is not a permission

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0057-repository-settings.md (AC15–AC20)
- **ADRs:** 0076, 0069, 0070, 0022
- **Owner:** unassigned

## Goal

The browser half of SPEC-0057. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0057 AC15–AC20 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **No disabled controls.** A disabled control tells a reader they lack a permission. Visibility and
  membership are absent because the capability does not exist — SPEC-0055 AC7's rule, and AC16 tests
  the copy for the softer phrasings that would imply otherwise.
- **An archived repository is still writable.** AC17 renders that, because a label a reader
  misinterprets as read-only is worse than no label.
