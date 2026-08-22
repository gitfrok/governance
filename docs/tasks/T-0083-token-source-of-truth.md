# T-0083: `tokens.json` becomes the source, and `tokens.css` becomes output

- **Status:** In progress (2026-08-23)
- **Phase / Epic:** design system (ADR-0091)
- **Repo(s):** governance, webfrontend, super-repo
- **Spec:** ../specs/SPEC-0066-token-source-of-truth.md (AC1–AC7)
- **ADRs:** 0091 (the kit is the source), 0032 (generated artifacts are gated), 0027 (one submodule
  per commit), 0047/0069 lineage via SPEC-0047

## What this task does

Authors `webfrontend/design/tokens.json` over all 87 governed tokens with light and dark values,
generates `webfrontend/src/styles/tokens.css` from it, and gates both — freshness against the source
and the CVD laws against the values. Moves the `./UI` comp in beside them without its blocked CDN
imports. Amends SPEC-0047 from holding the values to constraining them.

The safety property is AC1: because the kit holds no value the governed layer does not already hold
(SPEC-0066's measurement — 0 of 22 shared names differ, and all 18 kit-only real values are renames
of governed tokens), the generated CSS must come out identical to today's. Any difference is an
authoring defect, not a design change.

## Order of work

1. **governance** — SPEC-0066 Approved, this task filed, SPEC-0047 amended. *(this commit)*
2. **webfrontend** — RED first: the freshness check and the AC1 equivalence check, both failing
   because there is no `tokens.json`. Then author it, then the generator, until both pass. Then the
   CVD gate (AC3), the comp move with imports stripped (AC6), and the four addition candidates
   resolved (AC7).
3. **super-repo** — the freshness gate wired into `make verify`, and pins.

## Acceptance criteria

Tracked in SPEC-0066. Recorded here as they are proven, with the evidence.

- [ ] **AC1** generated `tokens.css` is equivalent to the pre-change file, name for name and theme
      for theme; diff attached
- [ ] **AC2** all 57 consumed names resolve; 0 unresolved `var(--…)` over `webfrontend/src`
- [ ] **AC3** a CVD-law violation in `tokens.json` fails a check
- [ ] **AC4** drifted `tokens.css` fails `make verify`; in-step passes
- [ ] **AC5** SPEC-0047 AC2's hex-literal gate still passes, and still fails on a raw hex
- [ ] **AC6** no tracked file under `webfrontend/design/` references `fonts.googleapis.com` or
      `fonts.gstatic.com`
- [ ] **AC7** `--gf-muted`, `--gf-slice`, `--gf-sh-sm`, `--gf-sh-md` each matched to an existing
      governed token or added with a purpose and a CVD verdict

## Notes

- The kit is untracked until step 2 lands, so SPEC-0066's mapping table is normative against the
  version measured 2026-08-23. Re-measure before starting if it has changed.
- `--gf-font-display` (`'Baloo 2'`) is deliberately out of scope: whether to vendor the WOFF2 or
  retire the token is a font-hosting decision, and AC6 only forbids the CDN reference.
