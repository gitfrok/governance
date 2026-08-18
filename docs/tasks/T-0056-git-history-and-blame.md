# T-0056: History and blame in git-storaged

- **Status:** Done (2026-08-19) — backend@d72998d; SPEC-0053 AC1–AC6 proven
- **Phase / Epic:** 4 / EP-26 (Tier B)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0053-blame-and-history.md (AC1–AC6)
- **ADRs:** 0070, 0033, 0017, 0006
- **Owner:** unassigned

## Goal

PR-8 has named blame and history since Phase 1; neither was ever built. Both are `git` invocations
in the process that already shells out for `ls-tree` and `for-each-ref`.

## Acceptance criteria (test-first)

- [x] AC1: history — commits newest first, paged by a cursor bound to tenant, repository, revision
      and path.
- [x] AC2: blame — line ranges at a revision, each with the commit that last touched it.
- [x] AC3: both are `repo.read` through the existing `prepareRead`; no second decision.
- [x] AC4: **a path can never become a flag** — `--` before every caller-supplied path and after
      the revision, asserted on the argument list; `validRepositoryPath` separately refuses
      traversal, absolute paths and NUL (SPEC-0053 amendment 2026-08-19: a leading dash is a legal
      filename, so the separator is its defence, not the validator).
- [x] AC5: bounded — a page cap on history and a line cap on blame, and a capped blame says so.
- [x] AC6: every failure is the existing coarse `unavailable()`.

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

## Exit record (2026-08-19)

**AC1–AC6 green.** backend **d72998d**.

**AC4 was amended before implementing, not after failing.** It originally required
`validRepositoryPath` to reject a path beginning `-`. It does not, and tightening it would have been
wrong rather than merely late: **a filename beginning with a dash is legal in a repository**, and
refusing it would have made those files unbrowsable through `GetTree`, `GetFile` and `GetDiff` — a
regression to three shipped surfaces in the name of a defence already in place. Every call site on
this surface puts `--` before the path and after the revision, which is what makes a leading dash
inert. The criterion now names both mechanisms for what they each do.

`historyArgs` and `blameArgs` are named functions so the argument ORDER is testable without running
git. Running git would have proven only that this git, today, tolerated the input.

Blame collapses consecutive lines sharing a commit into ranges — the same information in the shape a
reader consumes it, instead of 5000 near-identical messages. Past the cap it stops reading and
reports `capped`, so a partial attribution cannot be rendered as a whole one.

Rename and copy detection are absent **and asserted absent**: both are heuristics, and a heuristic
rendered without its uncertainty is the overclaim this whole surface is about.

**Carried:** adding two RPCs to `RepositoryReader` is additive on the wire but not for a Go fake
implementing the client interface — the code-search `repocontent` fake gained both, each refusing as
"not a code-search route".
