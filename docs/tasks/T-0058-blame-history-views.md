# T-0058: The blame and history views

- **Status:** Done (2026-08-19) — webfrontend@38fcd95; SPEC-0053 AC10–AC14 proven
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0053-blame-and-history.md (AC10–AC14)
- **ADRs:** 0070, 0069, 0029, 0015
- **Owner:** unassigned

## Goal

Render history and blame — and render them as what they are. A commit's author is whatever the
committer's git config said; the platform never verified it.

## Acceptance criteria (test-first)

- [x] AC10: history on the file and tree surfaces; blame on the file surface.
- [x] AC11: **git identity is labelled as git identity, every time.** The copy enumeration forbids
      presenting an author as an account, member, user or platform actor; no avatar, no profile
      link, nothing implying a principal behind the name.
- [x] AC12: a capped blame says so and does not present partial attribution as whole.
- [x] AC13: no hex literal; units on every length; a refusal names no cause; the pins unmodified.
- [x] AC14: stub serves both including the capped case; captures regenerated and reviewed.

## Tests to write first

- vitest: the copy enumeration over every string this surface can render.
- vitest: the capped-blame rendering, asserted as distinct from a complete one.
- vitest: no avatar, no profile link, no element that would imply a platform principal.
- playwright: file → blame → history, and the capped journey.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Notes / open questions

- This is the phase's first trap that is about an identity rather than an absence. "Who wrote this
  line" reads as accountability, and the platform vouches for none of it.

## Exit record (2026-08-19)

**AC10–AC14 green.** webfrontend **38fcd95**.

The file surface gains Content / Blame / History as links rather than a script, so all three work
with JavaScript doing nothing.

**AC11 holds by absence as much as by presence.** Both views carry the note in words, both label the
name at the point of use — "git author", never a bare name — and both render **no avatar, no profile
link and no `<img>` at all**, which a test asserts directly. An avatar beside a name *is* the claim
that the platform knows who that is.

**The copy enumeration caught its own message for the second surface running.** The capped notice
read *"the rest is not shown as unattributed"*, which contains the word it forbids. Rewritten to
describe the unshown part as **unexamined** rather than as empty: *we did not look* and *we looked
and found nothing* are different facts, and only one is true. The check stayed blunt both times,
because a blunt check is what survives someone shortening the copy later.

**The blame client defaults `capped` to true when the field is absent.** Not knowing whether an
attribution is whole must not read as knowing that it is.

Dates render as the authored day rather than a relative phrasing: "3 days ago" is computed against
the reader's clock and drifts, while the date is a fact in the commit.

**Reviewed by eye:** `file-blame-capped` grayscale, `file-blame` deuteranopia, `file-history`
deuteranopia — the three variants carrying the git-identity note and the partial notice. The other
three variants of the same surfaces were regenerated but not opened, and this record says so rather
than implying a fuller review than was performed.
