# T-0067: Guard the authenticated root against becoming a marketing page

- **Status:** Done (2026-08-19) — webfrontend@ea0677f; AC1–AC4 proven
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** chore: acceptance criteria below (ADR-0078 decision 3; no behaviour change)
- **ADRs:** 0078, 0070, 0049, 0003
- **Owner:** unassigned

## Goal

ADR-0078 decides that the marketing page is served by a surface that never receives a session, on a
different origin, and that `webfrontend`'s root stays the repository list. Two of those three are
about a surface that does not exist yet. The third is about this one, it is already true, and
nothing enforces it.

The failure this guards is not someone deciding to break the rule. It is someone reasonably
concluding that an app whose front page requires a login should have a public front page — and
putting one at `/`, where it will grow a repository count, a customer logo wall, or a recent-activity
strip, each of which is a tenant-existence leak that looks like a small improvement.

## Acceptance criteria (test-first)

- [x] AC1: a test asserts `src/pages/index.astro` reads the caller's repositories through the BFF —
      that the root is an authenticated surface, not a static one.
- [x] AC2: a test asserts the root renders no unauthenticated marketing vocabulary — no pricing, no
      sign-up call to action, no product pitch — so a splash page replacing it fails rather than
      merely looking different.
- [x] AC3: the test names ADR-0078 in its failure message, so whoever trips it is told which
      decision they are crossing and where the marketing page is supposed to live instead.
- [x] AC4: no behaviour change — the two regression pins and every existing suite pass unmodified.

## Tests to write first

- vitest: the root's source imports the repository client and renders `RepositoryList`.
- vitest: the rendered root carries none of the marketing vocabulary AC2 names.

## Definition of Done

See ../process/definition-of-done.md. `light` ceremony — this adds a guard and changes nothing.

## Notes / open questions

- This does not build the marketing surface. ADR-0078's follow-up — where it lives — is unresolved,
  and the super-repo stores pins only, so it cannot be a directory here.

## Exit record (2026-08-19)

**AC1–AC4 green.** webfrontend **ea0677f**. No behaviour change.

**Verified it can fail**, which is this repo's standing rule for a gate (T-0002/T-0009's pattern):
replacing the root with a splash carrying *"get started free"*, *"trusted by"* and *"pricing"* fails
three of the four assertions. A gate that cannot fail is not a gate, and a guard written against a
mistake nobody has made yet is the easiest kind to write vacuously.

The failure message names ADR-0078 and says where the marketing page belongs instead. That matters
more here than usual: whoever trips this will be mid-task and reasonably confident they are improving
something, so the test has to argue rather than just refuse.

**What this does not do:** build the marketing surface. ADR-0078's follow-up — where it lives — is
unresolved and cannot be resolved from this repository, because the super-repo stores pins only
(invariant 25) and a submodule needs a repository that does not exist.
