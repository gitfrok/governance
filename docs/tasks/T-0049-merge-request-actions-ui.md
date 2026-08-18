# T-0049: Open, review and merge a merge request from the web UI

- **Status:** Done (2026-08-18) — webfrontend@6d61827; SPEC-0048 AC1–AC11 proven
- **Phase / Epic:** 4 / EP-25 (the full product surface)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0048-merge-request-actions.md (AC1–AC11)
- **ADRs:** 0070 (Tier A — may begin before that ADR is Accepted), 0069, 0015, 0006
- **Owner:** unassigned

## Goal

Make PR-9's write half reachable. The BFF has served create, review and merge since T-0016 and the
web frontend has never called any of them; a merge request can be read in the product but not acted
on. This task adds the three writes and nothing else — no new route, no contract change, no
approval count the `MRView` does not carry.

## Acceptance criteria (test-first)

- [x] AC1: open — form-encoded POST of `source_ref`, `target_ref`, `title`, `description`; the
      returned `MRView` is what renders. A JSON body must fail the test.
- [x] AC2: review — disposition + optional comment, carrying the rendered view's `version` and
      `head_revision`, neither defaulted nor invented. The disposition travels as the protobuf enum
      name (`REVIEW_DISPOSITION_APPROVE` / `_REQUEST_CHANGES` / `_COMMENT`), pinned by test against
      `contracts/proto/codereview/v1`.
- [x] AC3: merge — same `expected_version` discipline.
- [x] AC4: a refusal names no cause; the copy-enumeration test forbids "permission", "denied",
      "not allowed", "unauthorized", "blocked by policy" and "does not exist" on this surface.
- [x] AC5: a stale version reads as staleness and shows current state; an equal version reads only
      as "did not take effect". Both paths driven.
- [x] AC6: controls render identically for a session with no roles — no affordance is a permission
      claim.
- [x] AC7: dispositions enter `src/lib/status.ts` with glyph and word; the enumeration test covers
      them.
- [x] AC8: no two dispositions share a glyph or a label, and the pair is not the success/danger one
      (SPEC-0048 amendment 2026-08-18 — the original ≥ 25 L\* threshold is unsatisfiable with the
      shipped tokens; law 1 governs foreground-against-background, law 2 governs status-against-status).
- [x] AC9: `npm run check:tokens` stays at zero; every length value ships its unit.
- [x] AC10: `usage-regression-pins` and `readonly-cause` pass unmodified; `git diff` over both empty.
- [x] AC11: the e2e stub BFF serves the three writes with form parsing, a version counter and a
      refusal fixture; captures regenerated and reviewed per SPEC-0047 AC10.

## Tests to write first

- vitest: the write clients — form encoding asserted on the outgoing request body, not the call
  shape. A JSON body is the negative case.
- vitest: version discipline — a client called without the rendered view's version must not compile
  a request at all.
- vitest: the refusal-copy enumeration over every string this surface can render.
- vitest: stale-vs-equal version branching.
- vitest: disposition vocabulary in the existing status enumeration; luminance and glyph separation
  for approve vs request-changes.
- playwright: open → review → merge against the stub BFF, plus the refusal path.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Notes / open questions

- The BFF's writes are **form-encoded** (`r.ParseForm()` / `PostFormValue`). `setSecurityTriage`
  posts JSON and is not a template; copying it produces a request the handler reads as empty and
  refuses with the same 404 as everything else, which is the hardest possible failure to diagnose.
- Every failure is one coarse 404 by design (SPEC-0001). AC4 exists because the natural copy for a
  failed merge — "you do not have permission to merge" — is a claim this layer cannot support.
- `codereviewv1.ReviewDisposition_value[disposition]` is a Go map lookup: an unknown string yields
  `0` = UNSPECIFIED, which `validDisposition` then refuses. Posting `APPROVE` produces a review
  button that silently never works. Post the full enum name.
- `head_revision` is mandatory on review — `service.go:264` refuses an empty one.

## Exit record (2026-08-18)

**All eleven criteria green.** Closed in one webfrontend landing: **6d61827**. `webfrontend` only; no contract, backend or bff change.

**What now exists.** `src/lib/bff.ts` gains three form-encoded writes (`openMergeRequest`,
`submitMergeRequestReview`, `mergeMergeRequest`) plus `MR_DISPOSITION_WIRE`; `src/lib/mrAction.ts` is
new and owns the outcome vocabulary and the disposition table; `src/lib/status.ts` gains
`APPROVED` / `CHANGES_REQUESTED` / `COMMENTED`; three SSR routes under
`src/pages/api/repos/[repositoryID]/merge_requests/`; three components —
`MergeRequestActions.astro`, `OpenMergeRequest.astro`, `ActionOutcome.astro`; form, disposition-glyph
and note classes in `src/styles/tokens.css`. Tests: `mr-actions-bff`, `mr-actions-outcome`,
`mr-actions-route`, `mr-actions-render` (all four added to the build-gating `prebuild` list) and
`e2e/mr-actions.spec.ts`. Unit total 203 → 258; e2e 4 → 18; captures 15 → 21.

**Both traps the task warned about were real, and both were caught before code.**

- The BFF's MR writes are form-encoded. A JSON body — which every other write in this frontend uses —
  reaches `r.ParseForm()` as no fields and is refused with the same coarse 404 as a dead session.
  `tests/mr-actions-bff.test.ts` asserts the outgoing body and makes a JSON body a failing case.
- `codereviewv1.ReviewDisposition_value[disposition]` is a Go map lookup, so `APPROVE` — the string
  the backend's own domain type uses — resolves to `0` (UNSPECIFIED) with no error, is refused by
  `validDisposition`, and surfaces as that same 404. The three enum names are now pinned by test.
  A review button built the obvious way would never have worked and would have been undiagnosable
  from either side.

**AC8 was amended before it was implemented, not after it failed.** The original ≥ 25 L\* threshold
between the approve and request-changes tones is unsatisfiable: every status ink in `tokens.css`
sits between L\* 38 and L\* 46, because ADR-0069 law 1 governs foreground against background — which
they all satisfy — while law 2's redundant channel is what separates one status from another. The
criterion now tests glyph and word distinctness, which is the channel that actually carries it. The
reasoning is recorded in SPEC-0048 § Amendments.

**AC6 is the criterion most likely to be undone later.** The instinct is to hide the merge button
from someone who cannot merge. This surface is never told who can merge — the PDP decides and the
refusal is indistinguishable from every other refusal — so hiding the control would encode a guess
that renders as certainty. `mr-actions-render` asserts nothing is disabled and no copy claims
anything about what the reader may do.

**The capture review earned its place again, in a small way.** The first capture run showed the
merge request as MERGED at version 3, because the e2e write journey had mutated the shared stub
fixture before the capture ran. A capture that shows a different state depending on test order is
not a reviewable artifact, so the captures now read a `mr-capture` fixture no test writes to.

**Grayscale and deuteranopia reviewed** on `merge-request-actions` and `merge-request-stale-note`.
All three dispositions stay separable with hue removed: approve's teal collapses toward grey under
deuteranopia, and the ✓ glyph and the word carry it — which is the design working, not surviving.
A Playwright assertion reads the computed `::before` content of all three pills, so a disposition
that silently lost its glyph override and inherited its tone's glyph fails the run.

**Carried:** the MR view still shows no approval count or merge-gate outcome, because `MRView`
carries neither (SPEC-0048 open question 1). Showing them needs a BFF change and its own spec under
ADR-0070's ordering law. Recorded, not silently absent.
