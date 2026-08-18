# T-0051: Request, watch and read an evidence pack from the web UI

- **Status:** Done (2026-08-18) — webfrontend@1141bc5; SPEC-0050 AC1–AC11 proven
- **Phase / Epic:** 4 / EP-25 (Tier A — the routes that exist and have no UI)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0050-evidence-pack-surface.md (AC1–AC11)
- **ADRs:** 0070, 0069, 0029, 0015, 0006
- **Owner:** unassigned

## Goal

Make PR-17 true of the product, not only of the platform. The BFF has served the whole evidence-pack
surface since T-0026 and no UI has ever called it, so the only way to export a pack today is `curl` —
which is exactly the engineer involvement PR-17 excludes. Adds the Compliance destination the shell
has never had.

## Acceptance criteria (test-first)

- [x] AC1: request a pack for a closed range with optional repository scope; RFC3339 JSON; an open,
      inverted or unparseable range refused before a request is compiled.
- [x] AC2: assembly state, section counts, appendix count, range and scope render from the status
      route; counts only, never record content.
- [x] AC3: `final_chunk` is the only completeness signal — a `200 OK` whose body ends without one is
      truncated. A reader that trusts `response.ok` must fail this test.
- [x] AC4: a truncated pack never renders as a complete one; the copy says so in words and a glyph.
- [x] AC5: a section with `complete: false` OR any gap renders degraded; both fixtures driven.
- [x] AC6: refusal names no cause — SPEC-0048 AC4's copy enumeration applies verbatim.
- [x] AC7: `ASSEMBLING` joins `PENDING`/`READY`/`FAILED`; the four are pairwise distinct in glyph and
      word; `FAILED` renders its `failure_reason` when present and invents nothing when absent.
- [x] AC8: the Compliance destination appears once, marked by `aria-current` + weight + rule, and is
      backed by a BFF route; a test asserts no nav destination lacks one.
- [x] AC9: `npm run check:tokens` stays at zero; every length value ships its unit.
- [x] AC10: `usage-regression-pins` and `readonly-cause` pass unmodified; `git diff` over both empty.
- [x] AC11: stub BFF serves all three routes with a never-final NDJSON stream and an incomplete
      section; capture fixtures write-free; captures regenerated and reviewed.

## Tests to write first

- vitest: the NDJSON reader — a stream ending without `final_chunk` returns truncated; a stream with
  one returns complete. Drive both at HTTP 200.
- vitest: the reader's chunk and byte ceilings, asserted as truncation rather than success.
- vitest: the request client — range validation before a request is compiled.
- vitest: the copy enumeration over every string this surface can render.
- vitest: section degradation — `complete: false` with no gaps, and `complete: true` with a gap.
- vitest: pack-state vocabulary distinctness, including the new `ASSEMBLING`.
- vitest: the nav destination-has-a-route assertion over the shell.
- playwright: request → status → read, plus the truncated-stream journey.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Notes / open questions

- **`getPack` writes 200 and the content type on the FIRST chunk.** A failure after that returns
  without an error status, so the consumer sees a truncated body with a 200. `response.ok` is not a
  success signal on this route — it is on every other route in `bff.ts`, which is what makes this
  easy to get wrong by pattern-matching.
- On a SOC 2 walkthrough, a pack that looks whole and is not is the worst output this product can
  produce. AC3 and AC4 are that risk, written down.
- No `/compliance` index page: it would be a nav destination with no route behind it.

## Exit record (2026-08-18)

**All eleven criteria green.** Landed with T-0052 in one webfrontend commit, **1141bc5** — the two
are one surface: they share the Compliance destination, link to each other, and touch the same four
files, so splitting them would have produced a first commit whose tests referenced symbols the
second added. One commit per submodule still holds.

**What now exists.** `src/lib/evidenceStream.ts` (the NDJSON reader and its ceilings),
`src/lib/evidence.ts` (copy table, the four pack states), `src/components/EvidencePackView.astro`,
`src/pages/compliance/evidence-packs/index.astro`, the SSR request relay, and the **Compliance**
destination in `Layout.astro`. Tests: `evidence-stream`, `evidence-bff`, `evidence-render`,
`evidence-route`, all four added to the build-gating `prebuild` list.

**The trap was real and it is the inverse of every other read in this frontend.** `getPack` writes
`200 OK` and `application/x-ndjson` on the **first** chunk, so a failure after that point returns and
the consumer sees a truncated body with a success status. `response.ok` — the signal every other
client in `bff.ts` uses — reports a half-assembled pack as whole. `readPackStream` therefore treats
truncation as the **default** and clears it only when the backend's own final marker arrives last. A
final marker in the middle leaves it set: a stream that continued past its stated end is not a pack
this layer understands, and guessing is exactly what it must not do.

**The grayscale review found a defect no DOM assertion could.** The truncated pack rendered a
**"✓ Ready" badge above the notice saying the pack was not whole.** Both strings were present and
both were true — READY is the *assembly* state, and assembly did succeed; the stream is a separate
act that was cut short. But the badge is the most glanceable element on the page, so a reader who
skimmed it stopped there and took the pack as complete. That is the exact failure AC4 exists to
prevent, and every assertion passed while it was on screen. The notice now precedes the badge, the
badge is labelled `assembly ·`, and a test asserts the document order rather than mere presence.

**Carried:** a pack is rendered, never downloaded — no route serves it as a file (SPEC-0050 open
question 1). Assembly is asynchronous with no notification and the page deliberately does not poll:
the backend has never told this layer how long assembly takes, so a timer would be the frontend
guessing (open question 2). Anchors are shown so a consumer can verify elsewhere; verifying them
here would make this layer an authority on pack validity, which it is not (open question 3).
