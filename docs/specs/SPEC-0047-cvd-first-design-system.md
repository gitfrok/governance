# SPEC-0047: CVD-first design system for the web frontend

- **Status:** Proposed (2026-08-17) — blocked-by ADR-0069 acceptance
- **Owner:** platform
- **Context(s):** Web frontend (renders) · BFF (serves the data these surfaces read) — ADR-0022
- **ADRs:** 0069 (decides this), 0015 (UX principles, unchanged), 0019 (Astro + React SSR), 0049
  (session affordance)
- **Task(s):** T-0045 (AC1–AC4), T-0046 (AC5, AC6), T-0047 (AC7, AC8), T-0048 (AC9, AC10)

## Problem / context

`webfrontend/src` has no design tokens. Every colour is a hex literal inline in the component that
uses it, the palette imitates GitHub's greys, and the diff view encodes add/remove with the exact
red/green pair the brand kit exists to reject. ADR-0069 adopts `gitfrok-brand-identity-v2` and makes
the three CVD laws binding; this spec says what "adopted" means in testable terms.

Scope is deliberately **re-skin and restructure, not new features**. Every surface named below is
already served by the BFF today. The `./UI` prototype also shows Issues, Releases, a pipelines list,
repository Settings and an Admin area — none of which has a BFF surface or a PRD requirement, and
none of which is in scope here (see Out of scope).

## The surfaces in scope, and what backs them

| Surface | BFF route today | PRD |
|---|---|---|
| App shell (nav, auth affordance, theme) | `/login`, `/logout` via ingress | — |
| Repo browse: tree, file, raw | `/v1/repositories/…` | PR-8 |
| Diff view | `/v1/repositories/…` | PR-8 |
| Merge request detail + review + merge | `GET/POST /v1/repositories/{id}/merge_requests/{mr}` | PR-10 |
| Security dashboard + findings + triage | `/api/v1/security/*` | PR-14 |
| Usage view | `GET /api/v1/usage/view` | PR-23 |
| Evidence packs + auditor grants | `/api/v1/audit/*` | PR-17, PR-18 |
| Code search | `/api/v1/search/*` | PR-16 |

## In scope

- One governed token layer, both themes, consumed by every component.
- A fitness check that fails the build on a hex literal in a component.
- Self-hosted WOFF2 for Inter, Baloo 2 and JetBrains Mono.
- Re-encoding every status and the diff per the CVD laws.
- Restructuring the shell's navigation to match the prototype's information architecture, limited to
  destinations that exist.

## Out of scope

- **Issues, Releases, a pipelines list, repository Settings, the Admin area, and the marketing
  landing page.** The prototype shows all six; none has a BFF surface or a `PR-#`, and inventing one
  would be scope this spec does not own. Recorded so the gap between prototype and product is a
  written decision rather than an omission.
- Deepfreeze (dark) as a *user-facing* setting — the tokens ship, the toggle does not (ADR-0069
  decision 3, open).
- Any change to what the BFF returns. This spec renders what exists.

## Acceptance criteria (test-first)

- [ ] **AC1 — one token layer, both themes.** Every colour, radius, shadow, motion duration and
      focus-ring value in the product resolves from a single token definition carrying a Frost
      (light) and a Deepfreeze (dark) value. The token names and values are those in *Binding
      tokens* below; a test asserts the shipped stylesheet defines every token in that table, in
      both themes.
- [ ] **AC2 — no hex literals in components.** A check over `src/**` fails on any hex colour literal
      outside the token definition file. The check names the file and line, and it runs in the same
      build-blocking position as the existing vitest pins.
- [ ] **AC3 — fonts are self-hosted.** No request to `fonts.googleapis.com` or `fonts.gstatic.com`
      appears in any shipped page. Inter, Baloo 2 and JetBrains Mono are served from the app's own
      origin as WOFF2, with `font-display: swap`.
- [ ] **AC4 — focus is visible everywhere.** Every interactive element renders a 2 px `#0072B2`
      focus ring with 2 px offset, in both themes; no rule removes an outline without replacing it.
- [ ] **AC5 — the diff is blue/orange with gutter markers.** Added lines use `gf.diff.add.bg`,
      removed lines `gf.diff.del.bg`, and every changed line carries a `+` or `−` in the gutter as
      text. A test asserts the marker is present in the DOM independently of any colour, so the diff
      is readable with colour rendering off entirely.
- [ ] **AC6 — no status is colour-only.** Every status the product renders — pipeline, finding
      severity, envelope state, read-only cause, merge-gate outcome, evidence-pack status — carries
      a glyph *and* a text label beside its colour. A test enumerates the rendered status
      vocabulary and asserts each member has a non-colour channel; a new status with colour only
      fails it.
- [ ] **AC7 — the security dashboard and MR findings render on tokens** with severity encoded by
      glyph and label, not hue alone, and the triage controls meeting AA contrast in both themes.
- [ ] **AC8 — the usage view keeps its meaning.** The existing `usage-regression-pins` and
      `readonly-cause` suites pass **unmodified**: "not metered" never renders as zero, no commercial
      state renders read-only, and every read-only condition still names its cause. A reskin that
      needs one of those tests edited has changed behaviour and is refused.
- [ ] **AC9 — charts use the Okabe–Ito order.** Any chart or multi-series visual uses the fixed
      eight-colour order, varies dash pattern on lines, and ships a visible legend. No series pair is
      red vs green.
- [ ] **AC10 — the grayscale gate is an artifact, not a promise.** For each surface in scope, a
      Playwright screenshot is captured under a grayscale filter and under a deuteranopia
      simulation, and the run is recorded in the task's exit record. Automating the *comparison* is
      ADR-0069's open decision 4 and is not required here; capturing the evidence is.

## Binding tokens

These are the values ADR-0069 decision 6 moves into governance. Frost is the default render.

| Token | Frost (light) | Deepfreeze (dark) |
|---|---|---|
| `gf.paper` | `#F7F9FB` | `#15202B` |
| `gf.surface` | `#FFFFFF` | `#1E2A38` |
| `gf.soft` | `#EDF2F7` | `#243242` |
| `gf.ink` | `#1B2A3A` | `#E8EEF4` |
| `gf.ink.muted` | `#5A6B7C` | `#9FB0C0` |
| `gf.line` | `#DCE4EC` | `#33465A` |
| `gf.stick` | `#9AA5B1` | `#6E7E8F` |
| `gf.code.bg` | `#F1F5F9` | `#101923` |
| `gf.action` | `#0072B2` | `#0072B2` |
| `gf.action.hover` | `#005E94` | `#1F86C9` |
| `gf.action.ink` | `#0072B2` | `#7CC6EE` |
| `gf.success` / `.ink` | `#009E73` / `#00664B` | `#2FC499` / `#2FC499` |
| `gf.danger` / `.ink` | `#D55E00` / `#A34700` | `#F07B2D` / `#F07B2D` |
| `gf.warn` / `.ink` | `#E69F00` / `#8A6100` | `#F2B33D` / `#F2B33D` |
| `gf.info` / `.ink` | `#56B4E9` / `#0072B2` | `#7CC6EE` / `#7CC6EE` |
| `gf.diff.add.bg` / `.ink` | `#E3F0FB` / `#0072B2` | `#1C3A52` / `#7CC6EE` |
| `gf.diff.del.bg` / `.ink` | `#FCEBD4` / `#A34700` | `#4A3010` / `#F2B33D` |
| Brand ramp | `gf.frost #A6D8F5` · `gf.sky #56B4E9` · `gf.blue #1F86C9` · `gf.deep #0B5E96` · `gf.mango #E69F00` | same (brand constants) |

Shape and motion: controls `10px`, cards `16px`, pills `999px`; motion `120/200/320ms` ease-out with
`prefers-reduced-motion` collapsing to an opacity fade; focus ring 2 px `#0072B2` + 2 px offset.
Type: Inter 400/500/600 at a 14 px app base, Baloo 2 600/700 for display ≥ 20 px, JetBrains Mono for
code, diffs, logs and SHAs.

Status glyphs are mandatory, not decorative: success `✓` filled circle, danger `✕` filled circle,
warning `!` triangle, info `●`, running animated ring, pending hollow circle.

## Test plan

- **vitest (unit/DOM):** token completeness (AC1), focus-ring presence (AC4), diff gutter markers
  independent of colour (AC5), the status-vocabulary enumeration (AC6), severity encoding (AC7).
- **Build-blocking check:** the hex-literal gate (AC2) and the no-CDN-font assertion (AC3), wired
  beside the existing `prebuild` pins.
- **Unmodified existing suites:** `usage-regression-pins`, `readonly-cause` (AC8).
- **Playwright:** grayscale and deuteranopia captures per surface (AC10).

## Non-functional

Astro's island model stays: the shell and every read-only surface render server-side with no
hydration, and `client:*` directives appear only on genuinely interactive islands (triage controls,
the command palette, the review form). The token layer is a stylesheet, not a runtime — no
JavaScript is required for a correct first paint in either theme.

## Open questions

- Whether the command palette ADR-0015 names is in this phase or the next. It is interaction, not
  colour, and no task below claims it.
- Thai typography (ADR-0069 open decision 2) — unresolved, and no surface in scope ships Thai copy.
