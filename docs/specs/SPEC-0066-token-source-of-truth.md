# SPEC-0066: `tokens.json` as the design system's source, and the derivation that proves it

- **Status:** Draft (2026-08-23) — awaiting owner approval; ADR-0091 is Accepted, so RED may begin
  once this is Approved.
- **Owner:** platform
- **Context(s):** webfrontend (the token layer and its consumers); governance (the CVD laws and the
  constraints the source must satisfy)
- **ADRs:** ADR-0091 (Accepted — the kit becomes the source of truth; supersedes ADR-0069),
  ADR-0032 (generated artifacts are gated for freshness), ADR-0027 (one submodule per commit)
- **Amends:** SPEC-0047 — from *holding* the binding token values to *constraining* them
- **Task(s):** — (to be filed once Approved)

## Problem / context

ADR-0091 made the `./UI` kit the design system's source of truth and left three things to this
spec: pick the naming vocabulary, enumerate what has to be authored, and define the derivation.

The measurements below were taken on 2026-08-23 against `UI/gitfrok.dc.html` and
`webfrontend/src/styles/tokens.css`. They decide most of this spec, and one of them decides it in a
way ADR-0091 did not anticipate.

| fact | value |
|---|---|
| Tokens in the governed layer | 87 |
| Custom properties declared in the kit | 47 |
| Names in both | 22 |
| **Shared names whose value differs** | **0** |
| Kit-only names that are aliases onto another token (`--color-ink: var(--gf-ink)`) | 7 |
| Kit-only names with real values | 18 |
| Kit names declared twice for light and dark | 24 |
| Governed names consumed by the product | 57 distinct, 1030 `var(--…)` references, 46 files |

**Every one of the 18 kit-only real-valued names resolves to a governed token that already holds the
same value**, under a different name:

| kit | governed | relationship |
|---|---|---|
| `--gf-add-bg`, `--gf-add-ink`, `--gf-del-bg`, `--gf-del-ink` | `--gf-diff-add-bg`, `--gf-diff-add-ink`, `--gf-diff-del-bg`, `--gf-diff-del-ink` | identical values, in **both** themes |
| `--color-ember` `#D55E00` | `--gf-danger` | identical |
| `--color-gold` `#E69F00` | `--gf-warn` | identical |
| `--color-indigo` `#0072B2` | `--gf-action` | identical |
| `--color-indigo-hover` `#005E94` | `--gf-action-hover` | identical |
| `--color-indigo-pressed` `#0B5E96` | `--gf-deep` | identical |
| `--color-succeeded` `#009E73` | `--gf-success` | identical |
| `--radius-card` `16px`, `--radius-control` `10px` | `--gf-radius-card`, `--gf-radius-control` | identical |
| `--font-sans`, `--font-mono` | `--gf-font-ui`, `--gf-font-code` | same families; the governed stacks are longer |
| `--gf-muted`, `--gf-slice`, `--gf-sh-sm`, `--gf-sh-md` | present in the kit, absent by name from the governed layer | the only genuine additions to reconcile |

So the conclusion this spec has to record plainly: **the kit contributes no value the governed layer
does not already hold.** It is a 47-name view of an 87-token system, in which 7 names are aliases,
18 are renames of governed tokens, and at most 4 are additions. Promoting it is therefore a renaming
and derivation exercise, not a change to how the product looks — which is what makes AC1 below
possible and is the strongest safety property this change has.

## Design

**1. The governed vocabulary is canonical (owner decision, 2026-08-23).** `tokens.json` uses the
existing 87 names. Measured basis: the product makes 1030 `var(--…)` references over 57 distinct
names in 46 files, and the kit's own `--color-*` names are largely aliases onto the same `--gf-*`
vocabulary, so the two are one vocabulary wearing two labels. Kit names winning would rewrite up to
1030 references and require inventing names for the 65 tokens the kit never had.

**2. The 25 kit-only names get one of three dispositions, and no fourth.**
- The 7 aliases are **not** tokens. They may remain in the comp as a compatibility layer; they do
  not enter `tokens.json`, because a token whose value is another token is a reference, not a value.
- The 18 renames enter under their governed name, at their existing value. The mapping table above
  is normative: each row is a rename, not a value change.
- `--gf-muted`, `--gf-slice`, `--gf-sh-sm`, `--gf-sh-md` are the only candidates for addition. Each
  must be either (a) matched to a governed token this spec has missed, or (b) added as a new
  governed token with a stated purpose and a CVD verdict. Silently adopting them is forbidden.

**3. `tokens.json` carries theme as a dimension.** 24 kit names hold two values, and the governed
layer already expresses the same thing through a second scope. A flat map would drop one of each
pair. Shape:

```json
{ "--gf-action": { "light": "#0072B2", "dark": "#7CC6EE",
                   "type": "color", "role": "primary action" } }
```
`type` and `role` are required: they are what the CVD gate in AC3 reads to know which tokens it must
judge, and a colour token with no role cannot be judged.

**4. `tokens.css` becomes generated output.** It is emitted from `tokens.json` by a generator in
`webfrontend`, is not hand-edited, and carries the same "do not edit" header as every other
generated artifact. A freshness gate fails when it drifts from its source, in the shape
`codegen-check` already uses for contracts (ADR-0032), wired into `make verify`.

**5. Placement, and what does not come across.** The kit lands in `webfrontend/design/` — source
lives in submodules (invariants 21–25), never at the super-repo root. `gitfrok.dc.html` may be
tracked there as a preview with its `fonts.googleapis.com` and `fonts.gstatic.com` imports removed
or rewritten to the self-hosted WOFF2 faces ADR-0069 decision 5 requires and ADR-0091 carries
forward. `.DS_Store`, `.thumbnail` and `uploads/` are not part of a design system and are not
tracked.

**6. SPEC-0047 is amended, not superseded.** Its clause holding the binding values becomes a clause
constraining them: the CVD laws, the light-by-default posture and the hex-literal gate (AC2) stay
exactly as they are and now apply *to the source*. Everything SPEC-0047 proves about the rendered
product continues to hold.

## Acceptance criteria

- **AC1 — the first landing is provably a visual no-op.** Generating `tokens.css` from the authored
  `tokens.json` produces a file whose token set and values are identical to today's, name for name
  and theme for theme. Any difference at all is a defect in the authoring, not an accepted change:
  0 of the 22 shared names differ today, and every kit-only name maps to a governed value, so there
  is nothing that legitimately changes. Proven by a diff against the pre-change file, attached to
  the task.
- **AC2 — nothing in the product changes name.** The 57 consumed names still resolve; the count of
  `var(--…)` references that fail to resolve against the generated layer is 0. Proven by a resolver
  check over `webfrontend/src`, not by inspection.
- **AC3 — the source is gated against the CVD laws.** A check reads `tokens.json` and fails when a
  colour token's role and value violate a CVD law from SPEC-0047 — the same laws, now enforced one
  layer earlier. A value edited in the source that would break colour-vision distinguishability
  fails the build rather than shipping. This is the acceptance criterion ADR-0091 says it owes.
- **AC4 — freshness.** With `tokens.css` committed, editing `tokens.json` and not regenerating fails
  `make verify`. Proven both ways: drifted fails and names both sides, in-step passes.
- **AC5 — the hex-literal gate still holds.** SPEC-0047 AC2's gate passes unchanged, and a raw hex
  outside the token layer still fails it. Moving the source must not weaken it.
- **AC6 — no blocked CDN in the tree.** No tracked file under `webfrontend/design/` references
  `fonts.googleapis.com` or `fonts.gstatic.com`. Proven by a grep in the gate, not by review.
- **AC7 — the four candidate additions are resolved explicitly.** `--gf-muted`, `--gf-slice`,
  `--gf-sh-sm` and `--gf-sh-md` each appear in the task record as either matched to an existing
  governed token or added with a purpose and a CVD verdict. None may be present in `tokens.json`
  without one of those two dispositions recorded.

## Open questions / assumptions

- **Assumption:** the kit as measured on 2026-08-23 is the kit being adopted. It is an untracked
  working file, so it can change under this spec until the commit that tracks it lands; the mapping
  table above is normative against the measured version, and a different version must be re-measured
  before the task starts.
- **Assumption:** the governed layer's 87 tokens are correct today. This spec moves where they live
  and does not re-litigate any value; SPEC-0047 remains the record of why each is what it is.
- **Open:** whether `--gf-font-display` (`'Baloo 2'`) stays. The kit's CDN import includes the face,
  and the governed layer declares the token, but ADR-0069 decision 5 requires self-hosted WOFF2 —
  so the face has to be vendored or the token retired. Not decided here; it is a font-hosting
  question, not a token-source one, and AC6 only forbids the CDN reference.
