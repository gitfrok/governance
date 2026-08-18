# SPEC-0048: Merge-request actions — open, review, merge from the web UI

- **Status:** Approved (2026-08-18), amended 2026-08-18 (AC2 and AC8 — see *Amendments*) — no new decision is required; PR-9 and PR-10 already bind and
  the BFF routes already exist. ADR-0070 places this in Tier A, which may begin before that ADR is
  Accepted.
- **Owner:** platform
- **Context(s):** Web frontend (renders and posts) · BFF (shapes and forwards) — ADR-0022. No
  backend or contract change: every route this spec consumes has been served since T-0016.
- **ADRs:** 0070 (tiering and the route-before-pixel law), 0069 (the token layer and the CVD laws),
  0015 (UX principles), 0019 (Astro + React SSR), 0049 (session), 0006 (deny-by-default PDP —
  the reason this surface may never infer an outcome)
- **Task(s):** T-0049

## Problem / context

PR-9 requires that a team can *open, review, comment on, approve, and merge* a merge request. The
BFF has served all four writes since T-0016:

| Route | Form fields | Returns |
|---|---|---|
| `POST /v1/repositories/{repository_id}/merge_requests` | `source_ref`, `target_ref`, `title`, `description` | `MRView` |
| `POST …/merge_requests/{merge_request_id}/review` | `disposition`, `comment`, `head_revision`, `expected_version` | `MRView` |
| `POST …/merge_requests/{merge_request_id}/merge` | `expected_version` | `MRView` |
| `GET …/merge_requests/{merge_request_id}` | — | `MRView` |

Only the `GET` has ever been called by the web frontend. The merge-request page renders title,
state, refs, head revision, creator, version, imported history and findings — and offers no action.
The core forge loop is reachable by `curl` and by nothing a human uses.

Two properties of the BFF surface shape everything below.

**The writes are form-encoded, not JSON.** `handler.go` calls `r.ParseForm()` and reads
`PostFormValue`; a JSON body reaches it as no fields at all, which the handler cannot distinguish
from a malformed request. The existing triage client (`setSecurityTriage`) posts JSON and is not a
template for these.

**Every failure is one coarse 404.** `denied()` returns `merge request unavailable` for a dead
session, an unknown repository, a policy refusal, a stale version and a merge the gate rejected —
deliberately, so the response distinguishes nothing about what exists or what is allowed
(SPEC-0001). The UI therefore cannot know *why* an action failed, and must not write copy that
implies it does.

## In scope

- Opening a merge request from the repository browse surface.
- Submitting a review with a disposition and an optional comment.
- Merging a merge request.
- The optimistic-concurrency handling all three writes require, and the honest reporting of a
  refusal that names no cause it does not have.
- The disposition vocabulary entering `src/lib/status.ts` under the ADR-0069 laws.

## Out of scope

- Any new BFF route, backend RPC or contract change. If a criterion below cannot be met with the
  four routes above, it is wrong and the spec is amended — not the contract.
- Rendering an approval count, a policy outcome, a required-approvals number, or any statement
  about who may merge. The MR page has never rendered these (T-0016), and this spec does not start.
- Threaded discussion, per-line review comments, reviewer assignment, labels, milestones. The BFF
  carries one `comment` string per review; a threaded UI would be rendering a data model that does
  not exist.
- Issues, releases, settings, admin — ADR-0070 Tier C.

## Contracts touched

None. `codereview/v1` and the BFF's `MRView` JSON are consumed unchanged.

## Data owned

None. The web frontend owns no state; every field rendered comes from the `MRView` the BFF returns
after the write, never from a local guess about what the write did.

## Acceptance criteria (each becomes a test)

- [x] **AC1** A merge request can be opened from the web UI: the form posts `source_ref`,
      `target_ref`, `title` and `description` as `application/x-www-form-urlencoded` to the BFF
      under the session cookie, and the created `MRView` is what the page then renders. A test
      asserts the encoding: a JSON body fails the test, because it silently reaches the handler as
      no fields.
- [x] **AC2** A review can be submitted with a disposition and an optional comment. The
      `expected_version` sent is the `version` of the `MRView` the page rendered, and
      `head_revision` is that view's head revision — neither is defaulted, invented, or read from
      the browser's URL. **The disposition travels as the protobuf enum name** —
      `REVIEW_DISPOSITION_APPROVE`, `REVIEW_DISPOSITION_REQUEST_CHANGES`,
      `REVIEW_DISPOSITION_COMMENT` — because the BFF resolves it through
      `codereviewv1.ReviewDisposition_value[disposition]`, a Go map lookup that yields `0`
      (`UNSPECIFIED`) for any string it does not know. A test asserts the exact three strings
      against the enum in `contracts/proto/codereview/v1`; sending `APPROVE` is a silent
      downgrade to UNSPECIFIED, which the backend then rejects as the same coarse 404 as a dead
      session. `head_revision` is likewise mandatory: the backend refuses an empty one.
- [x] **AC3** A merge can be submitted, carrying the same `expected_version` discipline as AC2.
- [x] **AC4** **A refusal names no cause.** Every failed write renders one message that states the
      action did not take effect and does not assert why. A test enumerates the copy: no rendered
      string on this surface may contain "permission", "denied", "not allowed", "unauthorized",
      "blocked by policy", or "does not exist" — because the 404 the UI received is the same for
      all of them, and every one of those words would be a claim the frontend cannot support.
- [x] **AC5** **A stale version is reported as staleness, not as failure.** When a write is refused
      and a re-read shows a `version` higher than the one submitted, the page says the merge
      request changed since it was loaded and shows the current state. When the re-read shows the
      same version, it says only that the action did not take effect. A test drives both paths.
- [x] **AC6** **No action affordance is a permission claim.** The merge and review controls render
      identically regardless of what the caller may do; the surface never hides or disables a
      control to signal an authorization outcome it has not been told. A test asserts the controls
      are present for a session with no roles, and that the refusal path — not the control's
      absence — is what carries the outcome.
- [x] **AC7** The disposition vocabulary (approve, request changes, comment) lives in
      `src/lib/status.ts`, and each member carries a glyph and a word beside its token class. The
      existing enumeration test covers the new members, so a disposition added later with colour
      alone fails on the day it is written (ADR-0069 law 2, SPEC-0047 AC6).
- [x] **AC8** Approve and request-changes are **not** told apart by colour. No two dispositions
      share a glyph, and no two share a label; the pair is not the success/danger one the diff
      view already refuses. A test asserts pairwise distinctness across the whole disposition set,
      so the separation survives grayscale by construction rather than by measurement.
- [x] **AC9** No hex literal is introduced: `npm run check:tokens` stays at zero findings, and
      every style value carrying a length ships its unit — the `gap: 24` class of silent drop the
      T-0048 capture review found is guarded by the existing test.
- [x] **AC10** `tests/usage-regression-pins.test.ts` and `tests/readonly-cause.test.ts` pass
      **unmodified**; `git diff` over both is empty for the whole task.
- [x] **AC11** The e2e stub BFF serves the three write routes with form parsing, a version counter
      and a refusal fixture, so AC4 and AC5 are exercised end to end rather than only at unit
      level. CVD captures are regenerated per SPEC-0047 AC10 and reviewed in grayscale and
      deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | The frontend asserts no tenant; identity travels only in the session cookie the SSR fetch forwards. AC4's refusal copy is what keeps a refusal from leaking existence. |
| G2 authorization | The PDP decides every write (ADR-0006). AC6 forbids the UI from pre-empting or mirroring that decision in an affordance. |
| G4 change control | PR-9's review and merge loop becomes reachable; the deciding backend records the decision as it already does. |
| G5 auditability | Each write carries a fresh `RequestID` minted by the BFF, unchanged by this work; the frontend adds no identity of its own. |

## Non-functional

- Server-rendered. The write posts go to SSR API routes under `src/pages/api/`, mirroring
  `api/security/triage.ts`: the browser never holds a BFF address.
- No client-side state machine. The rendered `MRView` after a write is the source of truth for what
  happened; the page does not optimistically render a state it has not been given.

## Open questions / assumptions

1. **The BFF's `MRView` carries no approval count or gate outcome**, so the page cannot show
   "2 of 3 approvals". This is assumed acceptable for Tier A; showing it needs a BFF change and
   therefore a separate spec under ADR-0070's ordering law.
2. **Opening a merge request needs a repository context the browse surface has** but the
   repository *list* does not exist (ADR-0070 Tier B, proposed PR-24). The open form therefore
   lives on the repository browse surface, not on a global "new merge request" page.
3. The `comment` field is a single string per review. Assumed sufficient; threaded discussion is
   out of scope above and would be a backend change first.

## Amendments

**2026-08-18, AC2 — the disposition is a protobuf enum name, not a word.** Found while writing the
task, before any code: `bff/internal/codereview/client.go:91` resolves the posted string through
`codereviewv1.ReviewDisposition_value[disposition]`. Go returns the zero value for a key a map does
not hold, so `APPROVE` — the obvious string, and the one the backend's own `api.Disposition` type
uses internally — becomes `REVIEW_DISPOSITION_UNSPECIFIED` with no error anywhere. The backend's
`validDisposition` then refuses it, and the refusal is the same coarse 404 as every other failure.
The failure mode is a review button that never works and cannot be diagnosed from either side, so
the wire vocabulary is now pinned by test against the contract.

**2026-08-18, AC8 — the original luminance threshold was unsatisfiable.** AC8 required ≥ 25 L\*
between the approve and request-changes token classes. Every status ink in `tokens.css` sits between
L\* 38 and L\* 46 — `--gf-success-ink` #00664B ≈ 37.9, `--gf-danger-ink` #A34700 ≈ 41.7,
`--gf-warn-ink` #8A6100 ≈ 44.1, `--gf-info-ink` #0072B2 ≈ 45.9 — so no pair of existing tones can
meet it. That is not a defect in the tokens: **ADR-0069 law 1's ≥ 25 L\* governs a foreground
against its background**, which every one of these satisfies, while **law 2's redundant channel** is
what separates one status from another. T-0047 already ships nine statuses on this basis. Rewriting
the tokens to satisfy the original wording would restyle every surface T-0047 landed, which is far
outside this task. AC8 now tests the channel that actually carries the distinction.
