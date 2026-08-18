# SPEC-0053: Blame and history — and the difference between a git author and a platform actor

- **Status:** Approved (2026-08-19) — no new decision is required; PR-8 has named blame and history
  since Phase 1 and neither was ever built. ADR-0070 Tier B, PR-25.
- **Owner:** platform
- **Context(s):** Repository/Git (git-storaged serves it) · BFF (shapes) · Web frontend (renders)
- **ADRs:** 0070 (Tier B and the ordering law), 0033 (bare repositories on block volumes), 0017
  (the Repository/Git read surface), 0029 (provenance — the distinction this spec turns on), 0069,
  0006
- **Task(s):** T-0056 (git-storaged), T-0057 (contract + bff), T-0058 (web)

## Problem / context

PR-8 requires that a developer can browse repo tree, file contents, **blame, history**, and diffs.
Tree, file and diff shipped in T-0015. Blame and history never did, and nothing in the tree serves
them: `RepositoryReader` has `GetTree`, `GetFile`, `GetDiff` and `GetMergeBase`, and that is all.

Both are `git` invocations in git-storaged, which already shells out for `ls-tree` and
`for-each-ref`. The work is not the git; it is what the answers are allowed to claim.

**The trap on this surface is attribution, and it is different in kind from the phase's earlier
ones.** Every previous trap was about a refusal being mistaken for an absence. This one is about an
identity being mistaken for an authenticated one.

A commit's author and committer are **whatever the person running `git commit` put in their local
config**. Git does not verify them; anyone can commit as anyone. The platform *does* know who
pushed — that identity is authenticated and audited — but it is not the same field and it is
frequently not the same person (a merge, an import, a rebase, a cherry-pick, a script). ADR-0029
already draws this line for imported review history: attested import records carry a
`declared_actor` that never becomes a platform actor and never satisfies a policy.

Blame is where that distinction gets lost. "Who wrote this line" reads as an accountability claim,
and a UI that renders `author` beside a platform avatar and a platform-looking name has asserted
that the platform vouches for it. It does not. On a SOC 2 walkthrough this is the same class of
error as the truncated pack that read as complete: a surface stating something stronger than the
data behind it supports.

**The second trap is mechanical and older than this product.** The path and revision reach a
command line. `git log -- <path>` with a path beginning `-` is a flag, not a path.

## In scope

- A ref's commit history, optionally narrowed to one path, paged.
- One file's blame at a revision: line ranges, each with the commit that last touched it.
- The attribution honesty rules below.

## Out of scope

- Any write. Nothing here creates, amends, reverts or cherry-picks.
- Blame across renames (`-C`/`-M` detection), and history following renames (`--follow`). Both are
  heuristics; a heuristic rendered without its uncertainty is the same overclaim this spec is about.
  Recorded as a follow-up, not built.
- Signature verification. A signed commit's *verification status* is a real fact and a genuinely
  useful one, but it needs its own decision about trust roots and its own surface. Until then this
  spec renders no signature and makes no statement about one.
- Graph rendering, branch topology, or anything that implies an ordering git does not guarantee.

## Contracts touched

`contracts/proto/repository/v1` — **additive**: `GetHistory` and `GetBlame` on `RepositoryReader`,
with their request/response messages. Both belong on `RepositoryReader` because git-storaged serves
them and they are reads of one named repository — unlike the registry list, which named none.

## Data owned

None. Every field comes from git via git-storaged.

## Acceptance criteria (each becomes a test)

### git-storaged (T-0056)

- [ ] **AC1** `GetHistory` returns a ref's commits — id, author name and email, committer name and
      email, both timestamps, and the subject — newest first, paged by an opaque cursor bound to
      tenant, repository, revision and path.
- [ ] **AC2** `GetBlame` returns one file's line ranges at a revision, each carrying the commit id
      that last touched it and that commit's author fields, with the range's start and end lines.
- [ ] **AC3** Both are `repo.read` decisions through the same `prepareRead` path as every other read
      on this surface. No new authorization path, no second decision.
- [ ] **AC4** **A path can never become a flag.** Every git invocation places `--` before any
      caller-supplied path, and a path that fails `validRepositoryPath` is refused before a command
      is built. A test drives paths beginning `-`, `--upload-pack=`, containing `..`, and NUL, and
      asserts no command is constructed.
- [ ] **AC5** Both are bounded: a page size cap on history, a line cap on blame, and a refusal
      rather than a truncation that could read as a whole answer. A blame that hits its cap says so.
- [ ] **AC6** Every failure is the one coarse `unavailable()` this surface already returns —
      nonexistent repository, unknown revision, unreadable path and unauthorized are the same answer.

### The wire and the BFF (T-0057)

- [ ] **AC7** Additive: `buf breaking` passes; no existing field number or enum value moves.
- [ ] **AC8** **The contract names git identity as git identity.** The author and committer fields
      are `git_author_name`, `git_author_email`, `git_committer_name`, `git_committer_email` — not
      `actor_id`, not `author`, not `user`. A caller cannot mistake them for a platform principal
      because the field names refuse the reading. A descriptor test asserts no field on these
      messages is named `actor_id` or `principal_id`.
- [ ] **AC9** The BFF shapes and forwards under the session; every failure is one coarse refusal.

### The views (T-0058)

- [ ] **AC10** History renders on the file and tree surfaces; blame renders on the file surface.
- [ ] **AC11** **Git identity is labelled as git identity, every time it appears.** The rendered
      output states that these names come from the commits themselves and are not platform
      identities. A test enumerates the copy: no rendered string may present an author as an
      account, a member, a user, or a platform actor, and the surface renders no avatar, no profile
      link and nothing else that would imply a platform principal behind the name.
- [ ] **AC12** A blame that hit its line cap says so, and does not present a partial attribution as
      a whole one.
- [ ] **AC13** No hex literal; units on every length; a refusal names no cause; the two regression
      pins unmodified.
- [ ] **AC14** The e2e stub serves both routes including the capped-blame case; captures
      regenerated per SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | The same `prepareRead` path as every other read; a repository outside the tenant is unavailable, indistinguishable from absent. |
| G2 authorization | `repo.read`, decided once, by the PDP that already decides it. |
| G5 auditability | AC8 and AC11 are the auditability criteria here: a git author rendered as a platform actor would put an unverified name into a reader's account of who did what. |

## Non-functional

- git-storaged never materialises a whole history or blame in memory; both stream and both are
  bounded.

## Open questions / assumptions

1. **Rename detection is off.** `--follow` and `-C` are heuristics, and a heuristic shown without
   its uncertainty is an overclaim. A later spec may add them *with* their uncertainty rendered.
2. **No signature verification**, so no statement is made about one. A commit that is signed and a
   commit that is not render identically, which is honest and unhelpful — closing that needs a
   decision about trust roots.
3. **Blame is at a revision, not at a line's whole life.** It answers what git answers.
