# T-0051: Request, watch and read an evidence pack from the web UI

- **Status:** Todo
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

- [ ] AC1: request a pack for a closed range with optional repository scope; RFC3339 JSON; an open,
      inverted or unparseable range refused before a request is compiled.
- [ ] AC2: assembly state, section counts, appendix count, range and scope render from the status
      route; counts only, never record content.
- [ ] AC3: `final_chunk` is the only completeness signal — a `200 OK` whose body ends without one is
      truncated. A reader that trusts `response.ok` must fail this test.
- [ ] AC4: a truncated pack never renders as a complete one; the copy says so in words and a glyph.
- [ ] AC5: a section with `complete: false` OR any gap renders degraded; both fixtures driven.
- [ ] AC6: refusal names no cause — SPEC-0048 AC4's copy enumeration applies verbatim.
- [ ] AC7: `ASSEMBLING` joins `PENDING`/`READY`/`FAILED`; the four are pairwise distinct in glyph and
      word; `FAILED` renders its `failure_reason` when present and invents nothing when absent.
- [ ] AC8: the Compliance destination appears once, marked by `aria-current` + weight + rule, and is
      backed by a BFF route; a test asserts no nav destination lacks one.
- [ ] AC9: `npm run check:tokens` stays at zero; every length value ships its unit.
- [ ] AC10: `usage-regression-pins` and `readonly-cause` pass unmodified; `git diff` over both empty.
- [ ] AC11: stub BFF serves all three routes with a never-final NDJSON stream and an incomplete
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
