# SPEC-0050: Evidence packs — request, watch, and read a date-ranged pack

- **Status:** Approved (2026-08-18) — no new decision is required; PR-17 already binds, ADR-0029,
  SPEC-0031 and SPEC-0032 already fix the behaviour, and the BFF has served all three routes since
  T-0026. ADR-0070 places this in Tier A, which may begin before that ADR is Accepted.
- **Owner:** platform
- **Context(s):** Web frontend (renders) · BFF (shapes and streams) — ADR-0022. No backend or
  contract change.
- **ADRs:** 0070 (tiering, the route-before-pixel law, and the nav decision below), 0069 (the token
  layer and the CVD laws), 0029 (evidence pack structure and provenance), 0015, 0019, 0049, 0006
- **Task(s):** T-0051

## Problem / context

PR-17 requires that a compliance owner can export a date-ranged evidence pack — approvals, policy
decisions, scan gates, access changes — sufficient for a SOC 2 Type II control walkthrough,
**without engineer involvement**. The last three words are the requirement. The BFF has served the
whole surface since T-0026:

| Route | Shape | Returns |
|---|---|---|
| `POST /api/v1/audit/evidence-packs` | JSON `{range_from, range_to, repository_id?}`, RFC3339 | `{pack_id, state}` |
| `GET …/evidence-packs/{pack_id}/status` | — | `PackStatusView` |
| `GET …/evidence-packs/{pack_id}` | — | **NDJSON stream** of `PackChunkView` |

No UI has ever called any of them. Today the only way to exercise PR-17 is `curl`, which is
precisely the engineer involvement the requirement excludes.

**The trap on this surface is the stream, and it is the opposite of every other read in the
frontend.** `getPack` writes `200 OK` and the `application/x-ndjson` content type on the *first*
chunk. A failure after that point cannot become a 404 — the handler returns, and the consumer sees
a **truncated stream with a 200 status**. So `response.ok` is not a success signal here. The
authority is `final_chunk: true` on the last chunk, and nothing about a pack is authoritative until
it arrives. A client written the way `securityDashboard` is written would render a truncated pack as
a complete one, which on a SOC 2 walkthrough is the worst failure this product can produce: a
document that looks whole and is not.

The second honesty rule is already carried by the wire and must survive rendering: a section carries
`complete` and `gaps[]`, and SPEC-0032 AC8 requires a degraded section to render degraded rather
than silently complete.

## In scope

- Requesting a pack for a closed date range with an optional repository scope.
- Watching assembly state through the status route.
- Reading a pack's stream and rendering its sections, anchors, gaps and completeness.
- The truncation and degradation rules above.
- A **Compliance** destination in the app shell (see *Navigation*).

## Out of scope

- Any new BFF route, backend RPC or contract change.
- Rendering pack payload bytes, provenance content or attested record contents beyond what
  `PackChunkView` already carries. The status surface in particular carries counts, never content
  (SPEC-0032 G9) — this spec does not widen that.
- Downloading the pack as a file, signing it, or verifying its anchors client-side. Verification is
  a consumer's act against the anchors the pack carries; doing it in the browser would make this
  layer an authority on pack validity, which it is not.
- Retention, deletion, or any pack lifecycle action. No route exists and none is proposed here.
- Auditor grants — SPEC-0051, its own surface.

## Navigation

The app shell's destinations are Repositories, Security and Usage. Evidence packs and auditor grants
have no home, and ADR-0070's ordering law permits one because both are backed by real routes.

**Decision: the shell gains one destination, `Compliance`, pointing at `/compliance/evidence-packs`.**
That page links to `/compliance/auditor-grants` in-page. There is deliberately **no `/compliance`
index page**: an index would be a nav destination with no BFF route behind it, which is the dead-nav
shape the ordering law exists to forbid, and SPEC-0047 refused to ship for exactly this reason.

## Contracts touched

None. `audit/v1` and the BFF's `PackReferenceView` / `PackStatusView` / `PackChunkView` JSON are
consumed unchanged.

## Data owned

None. Every field rendered comes from the BFF. Completeness, gaps and anchors are the backend's
assertions, forwarded — this layer computes none of them, so it cannot get any of them wrong.

## Acceptance criteria (each becomes a test)

- [x] **AC1** A pack can be requested for a closed range with an optional repository scope. The
      request posts RFC3339 timestamps as JSON; an open, inverted or unparseable range is refused
      before a request is compiled, so the cause is visible here rather than arriving as the coarse
      404 the BFF returns for everything.
- [x] **AC2** The pack's assembly state renders from the status route: state, the four control
      sections with their record counts, the appendix count, the range and any repository scope.
      Counts render as counts; no record content appears on this surface.
- [x] **AC3** **`final_chunk` is the only completeness signal.** The stream reader treats a stream
      whose last chunk lacks `final_chunk: true` as **truncated**, regardless of HTTP status. A test
      drives a `200 OK` response whose body ends without a final chunk and asserts the result is
      truncated — a reader that used `response.ok` fails it.
- [x] **AC4** **A truncated pack never renders as a complete one.** The rendered page says the pack
      is incomplete and that what is shown is not authoritative, and it does so in words and a glyph,
      not by omission or by a colour. A test enumerates the copy: no rendered string may state or
      imply the pack is complete when `final_chunk` was not seen.
- [x] **AC5** **A degraded section renders degraded.** A section with `complete: false` or any entry
      in `gaps[]` renders its incompleteness beside its record count, with each gap's bounds and
      reason shown. A test drives a section that is `complete: false` with zero gaps and one that is
      `complete: true` with a gap, and asserts both render as incomplete — neither field alone is
      the whole claim.
- [x] **AC6** A refusal names no cause. Every failure of request, status or stream — dead session,
      unknown pack, cross-tenant, policy refusal, malformed range — is the same coarse 404, so the
      copy enumeration from SPEC-0048 AC4 applies here verbatim: no rendered string may contain
      "permission", "denied", "not allowed", "unauthorized", "blocked by policy" or "does not exist".
- [x] **AC7** `ASSEMBLING` enters `src/lib/status.ts` beside the existing `PENDING`, `READY` and
      `FAILED`; the four pack states carry pairwise-distinct glyphs and words, so a reader tells them
      apart with hue removed. `FAILED` renders its `failure_reason` when the wire carries one, and
      renders nothing invented when it does not.
- [x] **AC8** The Compliance destination appears in the shell exactly once, marked current by
      `aria-current` plus weight plus a rule rather than by colour, and points at a page backed by a
      BFF route. A test asserts no nav destination lacks a route — the ordering law's mechanical
      check, applied to the shell as it now stands.
- [x] **AC9** No hex literal is introduced; `npm run check:tokens` stays at zero, and every style
      value carrying a length ships its unit.
- [x] **AC10** `tests/usage-regression-pins.test.ts` and `tests/readonly-cause.test.ts` pass
      **unmodified**; `git diff` over both is empty for the whole task.
- [x] **AC11** The e2e stub BFF serves all three routes, including an **NDJSON stream that never
      sends a final chunk** and a section that is `complete: false`, so AC3, AC4 and AC5 are
      exercised end to end. Capture fixtures are write-free from the start. CVD captures are
      regenerated per SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | The frontend asserts no tenant; a pack that is not the caller's is refused as the same 404 as one that does not exist, and AC6's copy keeps the rendering from leaking the difference. |
| G2 authorization | `evidence.pack.generate` and `evidence.pack.read` are PDP decisions (SPEC-0032 AC10). This surface predicts neither. |
| G5 auditability | Generation and retrieval are themselves audited by the backend; this layer adds no identity and suppresses no act. |
| G6 evidence | AC3–AC5 are the whole of PR-17's usefulness: a pack a compliance owner cannot trust to be complete is worse than no pack. |

## Non-functional

- Server-rendered. The stream is read on the Astro server and rendered as a page; the browser never
  holds a BFF address and never parses NDJSON itself.
- The reader is bounded: a chunk count and a byte ceiling, both refused as truncation rather than
  as success, so a pathological stream cannot hang the SSR request indefinitely.

## Open questions / assumptions

1. **A pack is rendered, not downloaded.** No route serves it as a file, and the stream is the only
   representation. A download would need a BFF change and its own spec under ADR-0070's ordering law.
2. **Assembly is asynchronous and there is no notification.** The status page is a read; a reader
   refreshes it. Polling on a timer is deliberately not specified — it would be the frontend
   guessing at an assembly duration the backend has never told it.
3. **Anchors are rendered, not verified.** Client-side verification would make this layer an
   authority on pack validity; the anchors are shown so a consumer can verify elsewhere.
