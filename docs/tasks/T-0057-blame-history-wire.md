# T-0057: GetHistory and GetBlame on the wire, and the BFF routes

- **Status:** Todo
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** governance, bff
- **Spec:** ../specs/SPEC-0053-blame-and-history.md (AC7–AC9)
- **ADRs:** 0070, 0029, 0022
- **Owner:** unassigned

## Goal

The additive contract change and the routes that shape it. Governance first (API change before
consumers), then the BFF.

## Acceptance criteria (test-first)

- [ ] AC7: additive — `buf breaking` passes; nothing existing moves.
- [ ] AC8: **the contract names git identity as git identity** — `git_author_name`,
      `git_author_email`, `git_committer_name`, `git_committer_email`. A descriptor test asserts no
      field on these messages is named `actor_id` or `principal_id`.
- [ ] AC9: the BFF shapes and forwards under the session; one coarse refusal.

## Tests to write first

- contract: `buf breaking`; descriptor assertion on the identity field names.
- bff unit: identity comes only from the session; a refusal names no cause.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- Field naming is the whole of AC8. A field called `author` invites a reader to treat it as one;
  `git_author_name` refuses the reading at the point where it would start.
