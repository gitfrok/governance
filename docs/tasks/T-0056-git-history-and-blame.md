# T-0056: History and blame in git-storaged

- **Status:** Todo
- **Phase / Epic:** 4 / EP-26 (Tier B)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0053-blame-and-history.md (AC1–AC6)
- **ADRs:** 0070, 0033, 0017, 0006
- **Owner:** unassigned

## Goal

PR-8 has named blame and history since Phase 1; neither was ever built. Both are `git` invocations
in the process that already shells out for `ls-tree` and `for-each-ref`.

## Acceptance criteria (test-first)

- [ ] AC1: history — commits newest first, paged by a cursor bound to tenant, repository, revision
      and path.
- [ ] AC2: blame — line ranges at a revision, each with the commit that last touched it.
- [ ] AC3: both are `repo.read` through the existing `prepareRead`; no second decision.
- [ ] AC4: **a path can never become a flag** — `--` before every caller-supplied path, and a path
      failing `validRepositoryPath` refused before a command is built. Drive `-`, `--upload-pack=`,
      `..` and NUL.
- [ ] AC5: bounded — a page cap on history and a line cap on blame, and a capped blame says so.
- [ ] AC6: every failure is the existing coarse `unavailable()`.

## Tests to write first

- unit: argument construction — the `--` separator is present and the rejected paths build nothing.
- unit: history paging — the cursor is bound to all four fields and refused when any differ.
- unit: blame parsing from `--porcelain` fixtures, including a file whose last line has no newline.
- unit: the blame cap reports as capped rather than as a complete attribution.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- The path reaches a command line. `git log -- <path>` with a path beginning `-` is a flag.
- Rename detection is deliberately off (SPEC-0053 open question 1): a heuristic rendered without its
  uncertainty is an overclaim.
