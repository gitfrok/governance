# ADR-0069: The product design system is CVD-first, token-only, and light by default

- **Status:** Accepted
- **Date:** 2026-08-17 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform (drafted from the `gitfrok-brand-identity-v2` kit and the `./UI` prototype)
- **Supersedes / superseded by:** — (supersedes nothing; see *Relationship to ADR-0015*)
- **Related:** ADR-0015 (GitHub-clean UX, and the design-system follow-up this discharges),
  ADR-0019 (technology stack — Astro + React SSR), ADR-0049 (BFF browser session; the auth
  affordance the shell renders), ADR-0056 (OWASP AISVS adoption — accessibility posture)
- **Governs:** PR-8 (repo browsing), PR-14 (findings dashboard), PR-17/PR-18 (evidence and auditor
  surfaces), PR-23 (usage view)

## Context

ADR-0015 fixed the UX *principles* — speed, keyboard-first, progressive disclosure, strong defaults,
and one unified security/compliance surface — and named its own follow-up: *"Establish a design
system (tokens + components) so this is enforced, not aspirational."* That follow-up was never
discharged. Two years of frontend work later, `webfrontend/src` carries **no tokens at all**: every
colour is a hex literal inline in an `.astro` or `.tsx` file, the palette is an ad-hoc imitation of
GitHub's greys, and there is no mechanism that could make a rule about colour hold.

Meanwhile the brand kit moved. `gitfrok-brand-identity-v2` (2026-07-05) replaced the v1 Slice Red
system for a stated reason: **red/green semantics are the worst possible pair for the ~8% of men
with deuteranopia or protanopia**, and a forge's primary signals — pipeline pass/fail, diff add/del,
finding severity — are exactly the signals v1 encoded that way. v2 is blue-led, derives its
functional palette from the peer-reviewed Okabe–Ito set, and makes three laws non-negotiable:
luminance before hue, never hue-only encoding, and a grayscale review gate.

Nothing in the product enforces any of that today, and the gap is not cosmetic. The diff view — the
single most-read surface in a forge — currently encodes added and removed lines the way every other
forge does, which is the encoding the brand kit exists to reject.

## Decision

**1. Adopt `gitfrok-brand-identity-v2` as the product design system**, and treat its three CVD laws
as binding on every UI surface: luminance separation ≥ 25 L\* between anything that must be told
apart, a redundant non-colour channel (glyph, shape, position, or text) on every status, and a
grayscale + deuteranopia review before merge.

**2. Tokens are the only source of colour.** Components carry token references, never hex literals.
The token set is defined once, in both themes, and a fitness check fails the build on a hex literal
in a component — the same posture the backend's boundary gates take. This is what makes ADR-0015's
"enforced, not aspirational" true rather than restated.

**3. Frost (light) is the only default.** Deepfreeze (dark) is tokenized in the same commit so the
two never drift, but whether it ships to users at GA is *not* decided here (see Open decisions).

**4. Diffs are blue/orange, never red/green**, with `+` and `−` gutter markers on every changed
line, so the diff reads with colour off entirely.

**5. Fonts are self-hosted WOFF2.** Org policy blocks the Google Fonts CDN; the prototype's CDN
imports are preview-only and must not reach the product.

**6. The binding token values live in governance**, in the spec this ADR carries — not in the
untracked `./UI` kit. The kit names `tokens-v2.json` as its source of truth, but that file is not in
the kit as delivered; the prototype's CSS custom properties are the de facto values, and copying
them into a governed artifact is how they stop being a working file on someone's laptop.

## Relationship to ADR-0015

This ADR **discharges ADR-0015's follow-up; it does not supersede the ADR** (ADR-0001: Accepted ADRs
are superseded, never edited, and there is nothing here to supersede). ADR-0015 decided *how the
product behaves and what it consolidates*: sub-100ms interactions, a command palette, progressive
disclosure, and security/compliance on one surface. None of that changes. "GitHub-clean" is read
here as an information-architecture and interaction principle — density, familiarity, and no
per-feature tab sprawl — not as an instruction to imitate GitHub's palette. Where the two could be
read to conflict, this ADR is narrower and later: the *structure* stays GitHub-clean, the *colour
and status encoding* become CVD-first.

## Consequences

**Positive.** The accessibility claim becomes testable rather than asserted — a grayscale screenshot
is a pass/fail artifact. A token layer makes theming, dark mode, and future white-labelling
mechanical. The hex-literal gate stops the drift that produced today's state from recurring.

**Negative.** Every existing surface needs reworking; there is no incremental path that leaves half
the product on hardcoded greys without looking broken. The build gains a font-hosting step. A
contributor who has only ever used GitHub's colour language must learn why `+` is blue here, and the
answer has to be in the docs, not in review comments.

**Neutral but load-bearing.** The existing build-blocking vitest pins — `usage-regression-pins` and
`readonly-cause` — must survive the rework unchanged. A reskin that breaks a regression pin is a
reskin that changed behaviour, and the pins exist precisely to catch that.

## Alternatives considered

- **Keep the GitHub-grey status quo and add an accessibility mode toggle.** Rejected by the brand
  mandate itself, and correctly: an accessibility mode is a second render path that receives half the
  testing, and the users who need it are the least likely to find the setting.
- **Adopt the tokens but keep red/green diffs** because every developer already reads them. Rejected
  — the diff is the flagship case for the whole decision. Keeping it would make the CVD claim false
  on the most-viewed screen in the product.
- **Generate a design system from first principles** rather than adopting the kit. Rejected: the kit
  is already peer-reviewed against a published colourblind-safe palette and carries its own
  verification checklist. Re-deriving it would produce something less defensible, slower.
- **Ship Deepfreeze (dark) as the default,** as v1 did. Rejected by the kit's own recorded feedback
  ("too dark"), and the decision is already made there; this ADR only records it.

## Open decisions (recorded, not decided here)

The brand kit carries four open decisions. They stay open, and none blocks this adoption:

1. App icon re-cut from the v2 slices.
2. Thai display face pairing — Baloo 2 has no Thai coverage.
3. Whether Deepfreeze ships at GA or post-GA.
4. Automated CVD simulation in CI (Playwright + a deutan transform) versus the manual PR checklist.
