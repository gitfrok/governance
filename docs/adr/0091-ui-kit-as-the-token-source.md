# ADR-0091: The `./UI` kit becomes the design system's source of truth (rev. 2 of ADR-0069)

- **Status:** Proposed
- **Date:** 2026-08-23
- **Deciders:** platform (requested by the deciding owner)
- **Supersedes:** ADR-0069
- **Related:** ADR-0015 (GitHub-clean UX), ADR-0019 (Astro + React SSR), ADR-0027 (one submodule per
  commit; invariants 21–25 on where source lives), ADR-0001 (Accepted ADRs are superseded, never
  edited), SPEC-0047 (the CVD-first design system, **Implemented**), T-0045
- **Governs:** PR-8, PR-14, PR-17/PR-18, PR-23

## Context

ADR-0069 adopted `gitfrok-brand-identity-v2` as the product design system and made six decisions.
Five of them are not in question here: the three CVD laws, token-only styling, light by default,
the hex-literal gate, and self-hosted WOFF2 fonts. This ADR revisits exactly one.

**ADR-0069 decision 6** put the binding token values in governance — in SPEC-0047 — and said why:
the kit named a `tokens-v2.json` it did not ship, the prototype's CSS custom properties were the de
facto values, and copying them into a governed artifact "is how they stop being a working file on
someone's laptop." The owner now wants the opposite: `./UI` as the source of truth, with governance
and the product deriving from it.

That is a reversal of an Accepted decision, so under ADR-0001 it is a new ADR that supersedes
ADR-0069 rather than an edit to it. What follows records the decision and its cost honestly,
including the parts that are more expensive than they look.

### What `./UI` is today, measured

`./UI` is untracked, 344 KB, seven files: `gitfrok.dc.html` (179 KB, a single-file design comp),
`support.js`, `gitfrok-data.js`, a `.thumbnail`, a `.DS_Store`, and an `uploads/` directory.

The token comparison is the part that decides how much work this is:

| | count |
|---|---|
| Tokens in the governed layer (`webfrontend/src/styles/tokens.css`) | **87** |
| CSS custom properties declared anywhere in `gitfrok.dc.html` | **17** |
| Names present in both | **9** |
| Names only in the prototype | **8** |

The eight are `--color-cream`, `--color-ember`, `--color-indigo`, `--color-ink`, `--font-sans`,
`--gf-add-bg`, `--gf-sh-sm`, `--radius-card`.

So the kit is **not a smaller version of the system**. It is an older, partly-translated naming
vocabulary that overlaps the governed one in nine names, and it contains no counterpart for 78 of
the 87 tokens the product actually uses. There is still no `tokens-v2.json`. Promoting the kit to
source therefore does not move a source of truth — it requires **authoring** one, and the material
to author it from is mostly in SPEC-0047, not in the kit.

`gitfrok.dc.html` also carries three external references, including
`fonts.googleapis.com/css2?family=Baloo+2…&family=Inter…&family=JetBrains+Mono…`. ADR-0069
decision 5 exists because org policy blocks that CDN and those imports "must not reach the
product". Making this file the source puts a blocked CDN import inside the source of truth.

## Decision

1. **`./UI` becomes the design system's source of truth**, superseding ADR-0069 decision 6.
   Governance and the product derive from it; SPEC-0047 stops being where the binding values live
   and becomes the record of what the source must contain and what the derivation must preserve.

2. **It moves into `webfrontend`, not the super-repo.** Invariants 21–25 keep source in the
   submodules; the super-repo holds pins, orchestration and dev manifests. A design system is
   source, so `webfrontend/design/` (exact path in the implementing spec) is where it lands.
   Tracking `./UI` at the super-repo root is not an option this ADR takes.

3. **The source is `tokens.json`, authored as part of this change — not the comp.** A 179 KB HTML
   file is a preview, and a preview cannot be a source of truth: nothing can validate it, and its
   values are entangled with layout. The decision is that the *kit* is the source, and the kit's own
   stated source is `tokens-v2.json`; that file must be written, covering all 87 tokens, before
   anything derives from it. Where the kit and SPEC-0047 disagree on a value, **the kit wins** —
   that is what this ADR changes — and every such difference is listed in the implementing spec so
   the change to the product's appearance is reviewed, not discovered.

4. **The derivation is generated and gated, like every other generated artifact.**
   `webfrontend/src/styles/tokens.css` becomes generated output, not hand-edited source, and a
   freshness gate fails when it drifts from `tokens.json` — the same shape as `codegen-check` for
   contracts (ADR-0032). SPEC-0047 AC2's hex-literal gate keeps running unchanged: it forbids raw
   colour outside the token layer, and that is orthogonal to where the tokens come from.

5. **The comp comes across as a preview artifact, and its CDN imports do not.** `gitfrok.dc.html`
   may be tracked beside the source for reference, with the Google Fonts imports removed or
   rewritten to the self-hosted WOFF2 faces ADR-0069 decision 5 requires — that decision is carried
   forward unchanged. `.DS_Store`, `.thumbnail` and `uploads/` are not part of a design system and
   are not tracked.

6. **Everything else in ADR-0069 is carried forward verbatim**: the three CVD laws, token-only
   styling, light by default, the hex-literal gate, self-hosted WOFF2 fonts, and its reading of
   ADR-0015 (structure stays GitHub-clean; colour and status encoding are CVD-first).

## Consequences

**Positive.** The design kit stops being an untracked file on one laptop, which is a real exposure
today: it is the artifact every design decision is drafted from and nothing versions it. Token
changes become reviewable diffs on a small JSON file instead of prose edits to a spec. A generated
`tokens.css` makes theming, dark mode and white-labelling mechanical, and the freshness gate makes
"the CSS matches the source" checkable rather than assumed.

**Negative / costs, stated plainly.**

- **This is not a promotion, it is an authoring task.** 78 of 87 tokens have no counterpart in the
  kit. The work is writing `tokens.json` from the governed values and then declaring the kit
  authoritative over them — which means the first version of the "source of truth" is largely
  transcribed *from* the artifact it is replacing.
- **A naming reconciliation nobody has scoped.** Nine names overlap and eight are kit-only. Either
  the kit's vocabulary wins and 78 governed names change (touching every consumer and the gate's
  expectations), or the governed vocabulary wins and the kit is renamed — in which case the kit is
  no longer the thing that was adopted. The implementing spec must pick one and say so.
- **SPEC-0047 is Implemented.** Amending an Implemented spec is a governance action with its own
  review, not a side effect of this ADR.
- **The direction of authority inverts.** Today a designer's working file cannot silently change
  the product; after this it can, because the file *is* the source. The freshness gate makes drift
  visible but does not make a value change reviewed by anyone who understands its accessibility
  consequences. The CVD laws stay in governance for exactly that reason, and a value that violates
  them must fail a gate rather than ship — the implementing spec owes an AC for that.
- **A blocked CDN inside the source.** Handled by decision 5 above, but it has to be actively
  stripped rather than assumed absent.

**Neutral.** SPEC-0047 keeps its job; what changes is whether it *holds* the values or *constrains*
them.

## Alternatives considered

- **Keep ADR-0069 decision 6.** The values stay in governance, `./UI` stays a laptop file. Rejected
  by the owner's decision; recorded because the cost above is the price of rejecting it, and the
  exposure it leaves — an unversioned kit — is the reason not to.
- **Track `./UI` as a reference comp only**, changing nothing about where binding values live. The
  cheapest way to end the laptop-file exposure, and it needs no reversal of anything. Not taken.
- **Generate the kit from governance** — the inverse: SPEC-0047 stays authoritative and the preview
  is derived from it. Keeps review where the accessibility argument lives, but does not give the
  owner an editable kit, which is the point of this decision.

## Implementation, if accepted

A spec first, then code, per ADR-0027 (separate commits, one submodule each):

1. **governance** — a spec under `docs/specs/` that: picks the naming vocabulary and lists every
   rename; enumerates the 78 tokens to be authored and any value where the kit differs from
   SPEC-0047 today; defines `tokens.json`'s schema; carries an AC for the CVD laws being gated
   against the source; and amends SPEC-0047 from "holds the values" to "constrains them".
2. **webfrontend** — `tokens.json` under `webfrontend/design/`, the generator, `tokens.css` as
   generated output, the comp with its CDN imports removed, and the freshness gate.
3. **super-repo** — the freshness gate wired into `make verify` beside `codegen-check`, and pins.

No product appearance may change silently: if the kit's values differ from today's, the spec lists
each difference and the change is reviewed as a visual change, not as a refactor.
