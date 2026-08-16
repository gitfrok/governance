# Phase 3.5 — The design system, and the product that renders on it

- **Status:** Active (2026-08-17) — ADR-0069 Accepted, SPEC-0047 Approved
- **Depends on:** Phase 3.1 (implementation-complete; T-0042 blocked on the cluster lane and does
  not gate this phase)
- **Decisions:** ADR-0069 (CVD-first, token-only, light by default) — Accepted 2026-08-17
- **Specs:** SPEC-0047
- **Tasks:** T-0045…T-0048
- **Repo(s):** governance (this plan, the ADR, the spec), then webfrontend (all four tasks)

## Why this phase exists

Three phases of backend depth now surface through a frontend with **no design tokens at all** —
every colour is a hex literal inline in the component that uses it. ADR-0015 named a design system
as its own follow-up in July 2026 and nothing discharged it, so the rule "consolidate governance
onto one clean surface" has been aspiration with no mechanism behind it.

The brand kit moved in the meantime. `gitfrok-brand-identity-v2` is blue-led and CVD-first for a
concrete reason: a forge's primary signals are pipeline pass/fail, diff add/remove and finding
severity, and v1 encoded all three as red/green — the worst available pair for the ~8% of men with
deuteranopia or protanopia. The product today ships that encoding on its most-read screen.

This phase is not a redesign of what the product does. **Every surface it touches already exists and
is already served by the BFF.** It is the phase where the way those surfaces render stops being
per-component improvisation.

## North Star

A developer with any form of colour vision deficiency — or a monochrome display, or a grayscale
screenshot in a ticket — reads every state this product renders without guessing: the pipeline that
failed, the lines a diff removed, the finding that is critical, the dimension that is not metered.
Not through an accessibility mode they had to find, but because that is the only render there is.
Underneath, one token layer makes it mechanical, and a build gate makes it stay true.

## Workstreams

| # | Workstream | Task | Delivers |
|---|---|---|---|
| 1 | Foundation | T-0045 | Token layer (both themes), self-hosted fonts, focus rings, the hex-literal gate, the app shell |
| 2 | The flagship surface | T-0046 | Repo browse, file, raw, and the blue/orange diff with gutter markers |
| 3 | Governance surfaces | T-0047 | Security dashboard, MR findings and triage, merge request detail, evidence packs, auditor grants |
| 4 | Commercial surface | T-0048 | Usage view and code search, with the existing regression pins unmodified |

Sequencing is strict: nothing in 2–4 can land before 1, because there is nothing to render on. Within
2–4 the order is free.

## What this phase must not do

1. **Not invent surfaces.** The prototype shows Issues, Releases, a pipelines list, repository
   Settings, an Admin area and a marketing landing page. None has a BFF route or a `PR-#`. They are
   out of scope in SPEC-0047 and stay out — a prototype is not a requirement.
2. **Not change what the BFF returns.** This phase renders what exists. A surface that needs new data
   is a different spec.
3. **Not edit a regression pin to make a reskin pass.** `usage-regression-pins` and `readonly-cause`
   are build-blocking and must pass unmodified. If one fails, the reskin changed behaviour.
4. **Not ship a dark-mode toggle.** Deepfreeze is tokenized so it cannot drift; whether users get it
   is ADR-0069's open decision 3.
5. **Not add an accessibility mode.** The accessible render is the only render — that is the whole
   decision.

## Exit criteria

- [x] ADR-0069 Accepted; SPEC-0047 Approved.
- [x] SPEC-0047 AC1–AC9 green. **AC10 is the phase's one carried gap** — see below.
- [x] The hex-literal gate and the no-CDN-font assertion run build-blocking; the gate's own
      fixture suite proves a deliberate violation fails, and the gate refused its author twice
      during the phase.
- [x] `usage-regression-pins` and `readonly-cause` pass **unmodified** at the final pin — `git diff`
      over both files is empty across the whole phase.
- [ ] **CARRIED — Grayscale and deuteranopia captures (SPEC-0047 AC10).** Not run, and not claimed
      anywhere. The encodings were built so the captures should pass — every status carries glyph
      and word, the diff carries text markers — but *should pass* is not evidence, and this criterion
      exists precisely because a design system's accessibility claim is the one most easily asserted
      without proof. Cause: capturing needs a Playwright run against the live surfaces, which needs
      the dev cluster and a browser install this phase did not stand up. It is the phase's one gap
      and it is named here rather than in a footnote.
- [x] Full gate matrix green at the final pin bump: webfrontend `tsc` + vitest 202/202 + build,
      super-repo `make verify` + `codegen-check` + `surfaces-check`.

## Risks

- **The kit's token file is missing.** `gitfrok-brand-identity-v2.md` names `tokens-v2.json` as its
  source of truth; the delivered kit does not contain it, and `./UI` is untracked working material.
  SPEC-0047 therefore copies the prototype's CSS custom properties into governance as the binding
  values. If the real `tokens-v2.json` surfaces later and disagrees, governance wins until an
  amendment says otherwise.
- **A reskin can silently change behaviour.** Mitigated by the two unmodified pin suites, and by
  taking the surfaces one task at a time rather than one sweeping commit.
- **The grayscale gate is manual.** Capturing evidence is required; comparing it automatically is
  ADR-0069's open decision 4. Until that closes, the gate depends on a human looking — recorded
  rather than papered over.
- **Prototype drift.** The prototype is a Vue-flavoured mock; the product is Astro + React SSR. Its
  value is information architecture and token values, not markup. Copying its DOM would fight the
  island model (ADR-0019).
