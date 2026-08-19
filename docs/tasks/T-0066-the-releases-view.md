# T-0066: The releases view

- **Status:** Done (2026-08-19) — webfrontend@1f5fd65; SPEC-0056 AC11–AC16 proven
- **Phase / Epic:** 4 / EP-27 (Tier C — first increment)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0056-releases-tags-and-notes.md (AC11–AC16)
- **ADRs:** 0075, 0071, 0070, 0022, 0069, 0006
- **Owner:** unassigned

## Goal

One repository's share of SPEC-0056, split along the ADR-0027 boundary. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0056 AC11–AC16 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **No artifacts.** ADR-0075 accepted the tags-and-notes increment only; an artifact field, an
  upload route or a download link re-opens signing, custody, retention and metering at once.
- **The tag is a mutable pointer.** A release records the commit it pointed at when published, and
  the surface says when the two have diverged. That is the point of the record existing.

## Exit record (2026-08-19)

**AC11–AC16 green.** webfrontend **1f5fd65**.

**The comparison happens here because nowhere else may hold both facts.** The Release context cannot
ask git what a tag means and Repository/Git knows nothing about releases, so the page is the only
place where the recorded commit and the tag's current target meet. Three states, kept apart: agrees
(and says nothing, because agreement is unremarkable), moved, and gone. A deleted tag and a
repointed one are different events and collapsing them would tell one story about two.

**Neither state is a failure**, and the tones say so: moving or deleting a tag is a thing
maintainers do, and the release remains an accurate record of what it was published against.

**The escaping test was wrong on first write**, and the correction is worth keeping. It asserted
`onerror=alert(2)` was absent from the output; that substring legitimately survives inside
`&lt;img src=x onerror=alert(2)&gt;`, where it is prose. What makes it harmless is the escaped
angle brackets, so the test now asserts the **tags are inert** rather than that the attribute text
vanished. A test that had "passed" by demanding the text disappear would have pushed someone toward
stripping content instead of escaping it.

**`bffPostForm` became generic and gained `BffWriteError`.** Making it generic alone broke the
merge-request clients' error contract, whose tests expect their own coarse message; carrying the
status on a typed error restores that while letting the publish relay branch on a 409 without
parsing prose.
