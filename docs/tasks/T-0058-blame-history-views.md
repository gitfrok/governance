# T-0058: The blame and history views

- **Status:** Todo
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0053-blame-and-history.md (AC10–AC14)
- **ADRs:** 0070, 0069, 0029, 0015
- **Owner:** unassigned

## Goal

Render history and blame — and render them as what they are. A commit's author is whatever the
committer's git config said; the platform never verified it.

## Acceptance criteria (test-first)

- [ ] AC10: history on the file and tree surfaces; blame on the file surface.
- [ ] AC11: **git identity is labelled as git identity, every time.** The copy enumeration forbids
      presenting an author as an account, member, user or platform actor; no avatar, no profile
      link, nothing implying a principal behind the name.
- [ ] AC12: a capped blame says so and does not present partial attribution as whole.
- [ ] AC13: no hex literal; units on every length; a refusal names no cause; the pins unmodified.
- [ ] AC14: stub serves both including the capped case; captures regenerated and reviewed.

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
