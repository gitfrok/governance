# T-0020: Contract schema gate — `buf lint` + `buf breaking` + codegen freshness

- **Status:** Todo — **ready to start** (ADR-0032 Accepted 2026-08-06; AC2 is settled as the rename)
- **Phase / Epic:** 0 / EP-9
- **Repo(s):** governance (`contracts/`, CI) → backend (`gen/`, CI) → bff (`gen/`, CI) →
  webfrontend (`src/gen`, CI) → super-repo (pin bump). ADR-0027 order, **one commit per repo**.
- **Spec:** chore — acceptance criteria below
- **ADRs:** **0032 (governing)**, 0022, 0027, 0031
- **Owner:** unassigned

## Goal
Make the required check that `../process/ci-gates.md` already claims — "contract schema (additive /
breaking-check)" — actually exist, and leave it green. Today `buf` runs in no CI in any repo, and
`buf lint` on `contracts/` fails with 13 `ENUM_VALUE_PREFIX` violations, so the Source of Truth
declares a policy it neither meets nor enforces.

## Acceptance criteria (test-first)
- [ ] AC1: `buf lint` runs on `contracts/` in governance CI, is a **required** check on `main`
      (ADR-0031 `main-integrity`), and passes. A PR introducing a lint violation fails.
- [ ] AC2: The 13 `ENUM_VALUE_PREFIX` violations in `proto/agent/v1/agent.proto` are **renamed** —
      `Cloud` → `CLOUD_*`, `HealthState` → `HEALTH_STATE_*`, `CommandType` → `COMMAND_TYPE_*` —
      per ADR-0032 as Accepted. Numbers and types are untouched (invariant 10), and
      `contracts/buf.yaml` gains no new except or `ignore_only`: the fallback was not taken.
- [ ] AC3: `buf breaking --against` the merge base with `main` runs in governance CI and is
      required. A PR that renumbers a field, changes a type, or renames an enum value **fails**;
      an additive field **passes**. Category is `FILE`.
- [ ] AC4: The three consumer references are updated in the same wave —
      `backend/cmd/controlplane-app/main.go` (`Cloud_GKE`),
      `backend/cmd/dataplane-app/main.go` and `bff/cmd/bff/main.go` (`HealthState_HEALTHY`) —
      each in its own repo's commit, and every repo's CI stays green.
- [ ] AC5: `backend`, `bff` and `webfrontend` each gate **codegen freshness**: regenerate from the
      pinned `contracts/` and fail on a non-empty `git diff` over `gen/` (`src/gen` for
      webfrontend). Verified reproducible on 2026-08-05 — all three regenerate byte-identically
      today, so this must pass on arrival, and a hand-edited `gen/` must fail it.
- [ ] AC6: The new checks are added to each repo's required-check context in
      `scripts/apply-rulesets.sh` (super-repo) and `apply-rulesets.sh check` stays green, so the
      gate blocks rather than merely runs (ADR-0031, T-0002 AC5).

## Tests to write first
- **contract (governance):** a fixture proto that trips `ENUM_VALUE_PREFIX` must fail `buf lint`;
  a fixture adding a field must pass `buf breaking` while one renumbering a field must fail it.
  Fixtures prove the gate is not vacuous — the T-0002/T-0009 pattern.
- **integration (consumers):** touch a generated file by hand and confirm the freshness check fails;
  revert and confirm it passes.
- **boundary:** unchanged — this task adds no import edges. `check-dep-direction.sh` must stay green
  (invariant 22: consumers generate *from* `contracts/`, never the reverse).

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
- **AC2 was decided by ADR-0032, Accepted 2026-08-06** — the rename, not the path-scoped fallback.
  Renaming a `v1` enum value keeps its number and type, so invariant 10 does not forbid it, but it
  does change the JSON/text encoding — precisely what AC3's gate rejects once the baseline is set.
  That is why the rename lands first and the baseline is taken from the renamed tree; the same
  change made after T-0020 would need a superseding ADR.
- **Order matters.** AC2 must land *before* AC3's baseline exists, or the rename becomes permanently
  ungateable. Sequence: governance (rename + lint + breaking) → backend, bff (references + freshness)
  → webfrontend (freshness) → super-repo (pin bump + ruleset contexts).
- **`buf breaking` needs history.** `actions/checkout` defaults to depth 1; the governance workflow
  needs `fetch-depth: 0` for the merge base to exist.
- **Why Phase 0.** The phase-0 exit criteria in `../plans/phase-0-foundations.md` require CI green on
  "unit + **contract** + boundary + policy/isolation + fitness-function tests". The contract half has
  no gate, so Phase 0 cannot exit without this. It is **not** reopening EP-0: that epic closed
  2026-08-04 with all four of its tasks Done and its criteria verified, and this gate was never one
  of them — `ci-gates.md` attributes its wired rows to T-0001/T-0002/T-0004/T-0005/T-0009 and leaves
  the contract-schema row unattributed. Hence a new epic, EP-9.
- **Scope boundary.** `buf format` is not gated, and the five existing `buf.yaml` excepts are not
  re-examined (ADR-0032 follow-ups).
