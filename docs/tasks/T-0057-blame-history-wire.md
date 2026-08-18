# T-0057: GetHistory and GetBlame on the wire, and the BFF routes

- **Status:** Done (2026-08-19) — governance@eb7b131, bff@1f38368; SPEC-0053 AC7–AC9 proven
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** governance, bff
- **Spec:** ../specs/SPEC-0053-blame-and-history.md (AC7–AC9)
- **ADRs:** 0070, 0029, 0022
- **Owner:** unassigned

## Goal

The additive contract change and the routes that shape it. Governance first (API change before
consumers), then the BFF.

## Acceptance criteria (test-first)

- [x] AC7: additive — `buf breaking` passes; nothing existing moves.
- [x] AC8: **the contract names git identity as git identity** — `git_author_name`,
      `git_author_email`, `git_committer_name`, `git_committer_email`. A descriptor test asserts no
      field on these messages is named `actor_id` or `principal_id`.
- [x] AC9: the BFF shapes and forwards under the session; one coarse refusal.

## Tests to write first

- contract: `buf breaking`; descriptor assertion on the identity field names.
- bff unit: identity comes only from the session; a refusal names no cause.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- Field naming is the whole of AC8. A field called `author` invites a reader to treat it as one;
  `git_author_name` refuses the reading at the point where it would start.

## Exit record (2026-08-19)

**AC7–AC9 green.** governance **eb7b131**, bff **1f38368**.

**AC8 is enforced as a contract property, not a naming convention.** `check-contracts.sh` gained
check 12: the compiled descriptor of `gitsaas.repository.v1.CommitIdentity` must carry no `actor_id`,
`principal_id`, `user_id` or `account_id`, and a paired fixture carrying `actor_id` proves the check
can fail. A future "convenience" field fails the gate on the day it is added rather than on the day
someone renders it as an account.

The BFF test asserts the same property on **the wire the browser actually reads**: the JSON carries
`git_author_name` and friends, and carries none of `"author"`, `"actor_id"`, `"principal_id"`,
`"user"` or `"account"`. That is where naming stops being a convention — it is the point at which a
consumer decides what a name means.

The shapes live in `internal/aggregate` rather than `internal/repositoryreader`, because
`repositoryreader` already imports `aggregate` and the dependency runs one way; it is where
`TreePage` and `FileChunk` already live.
