# T-0064: Releases context, durable store, and tag listing

- **Status:** Done (2026-08-19) — backend@4668f75; SPEC-0056 AC1–AC7 proven
- **Phase / Epic:** 4 / EP-27 (Tier C — first increment)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0056-releases-tags-and-notes.md (AC1–AC7)
- **ADRs:** 0075, 0071, 0070, 0022, 0069, 0006
- **Owner:** unassigned

## Goal

One repository's share of SPEC-0056, split along the ADR-0027 boundary. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0056 AC1–AC7 — as written in the spec.

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

**AC1–AC7 green.** backend **4668f75**. Eight integration proofs against the dev Postgres, **0
skips** — the count is what AC7 asks for, not the green summary.

**AC6 is enforced by structure rather than by discipline.** The Release context has no port that
could resolve a tag and never asks: not on publish, where the commit arrives already resolved, and
not on read, where the recorded one is returned as recorded. Asking would make it depend on
Repository/Git, which ADR-0022 forbids. The resolver lives in the dataplane composition root — the
same inversion the repository registry's `Authorizer` uses.

**`git-storaged`'s `ListTags` dereferences annotated tags** with `*objectname`. Without it an
annotated release tag would record the *tag object's* SHA as though it were a commit, and every
later comparison against it would be false. The failure would have been invisible until someone
compared, which is why it has its own test.

**No in-memory constructor.** Releases have never had one, and adding it would create exactly the
gap ADR-0071 was written to close: a record of what was announced that empties with a process.
