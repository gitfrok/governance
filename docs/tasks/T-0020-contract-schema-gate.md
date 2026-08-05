# T-0020: Contract schema gate — `buf lint` + `buf breaking` + codegen freshness

- **Status:** Done (2026-08-06) — AC1–AC4 and AC6 as written; **AC5 amended** (see the record)
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
- [x] AC1: `buf lint` runs on `contracts/` in governance CI, is a **required** check on `main`
      (ADR-0031 `main-integrity`), and passes. A PR introducing a lint violation fails.
      Verified by reintroducing `GKE = 1` and watching `check-contracts.sh` exit 1.
- [x] AC2: The 13 `ENUM_VALUE_PREFIX` violations in `proto/agent/v1/agent.proto` are **renamed** —
      `Cloud` → `CLOUD_*`, `HealthState` → `HEALTH_STATE_*`, `CommandType` → `COMMAND_TYPE_*` —
      per ADR-0032 as Accepted. Numbers and types are untouched (invariant 10), and
      `contracts/buf.yaml` gains no new except or `ignore_only`: the fallback was not taken.
- [x] AC3: `buf breaking` runs in governance CI against **the tip of `main`** (not the merge base —
      see the record) and is required. A PR that renumbers a field, changes a type, or renames an
      enum value **fails**; an additive field **passes**. Category is `FILE`.
- [x] AC4: The three consumer references are updated in the same wave —
      `backend/cmd/controlplane-app/main.go` (`Cloud_GKE`),
      `backend/cmd/dataplane-app/main.go` and `bff/cmd/bff/main.go` (`HealthState_HEALTHY`) —
      each in its own repo's commit, and every repo's CI stays green.
- [x] AC5 **(amended — original wording was not implementable; see the record)**: codegen freshness
      is gated in the **super-repo**, where the four repos are composed: `make codegen-check`
      regenerates all three consumers from the pinned `contracts/` and fails on any difference under
      `gen/` (`src/gen` for webfrontend). A hand-edited generated file fails it. Per-consumer
      gating stays blocked on the ADR-0027/0028 generated-type publishing follow-up.
- [x] AC6: The new checks block rather than merely run (ADR-0031, T-0002 AC5) — achieved with **no**
      `scripts/apply-rulesets.sh` change, because each gate rides inside an already-required
      context: the contract gates inside governance's `docs gates`, codegen freshness inside
      `super-repo fitness gates`. `apply-rulesets.sh check` → `rulesets: OK` on all five repos.

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

## Implementation record

| Repo | Merged | What |
|---|---|---|
| governance | `29a04af` (#18) | AC2 rename; `scripts/check-contracts.sh` + `scripts/testdata/lint-enum-prefix/` fixture; `buf lint` wired into the `docs gates` job (AC1) |
| governance | `64c4d6b` (#19) | AC3 `buf breaking` against `origin/main` + four fixtures (additive passes; renumber, retype, enum-rename each fail on their own rule); `fetch-depth: 0` |
| backend | `6e8cfe7` (#6) | AC4: regenerated `gen/proto/agent/v1`; `Cloud_GKE` → `Cloud_CLOUD_GKE`, `HealthState_HEALTHY` → `HealthState_HEALTH_STATE_HEALTHY` |
| bff | `9abf194` (#4) | AC4: regenerated `gen/`; `HealthState_HEALTHY` → `HealthState_HEALTH_STATE_HEALTHY` |
| webfrontend | `244f16a` (#3) | AC4: regenerated `src/gen` (no hand-written references to move) |
| super-repo | `78255d8` (#25) | AC5 (amended) `scripts/check-codegen-fresh.sh` + `make codegen-check` in CI; AC6 verification; all four pins bumped |
| governance | *(this PR)* | T-0020 Done; AC5 amended; `ci-gates.md` contract rows corrected |

**AC1 blocks immediately, and AC6 needs no ruleset change for it.** The contract gate is a *step*
inside the existing `docs gates` job rather than a new job, so it rides the required-status-check
context already registered in `main-integrity`. A new job would have meant a new context, which does
not block until the super-repo adds it — and `apply-rulesets.sh` maps one context per repo, so a
second would have been a data-structure change. Same reasoning applies to the consumer freshness
checks in AC5: put them inside `build + vet + arch gates` / `build + typecheck + test + arch gates`
and AC6 reduces to confirming `apply-rulesets.sh check` still passes.

**Why AC3 is not in this PR.** `buf breaking` compares against `main`, and `main` still carries the
pre-rename enums, so wiring it here would fail on the very commit that makes the tree correct —
ADR-0032's "the baseline starts after the rename". It lands in the next governance PR, once these
names are on `main`.

**The fixture is checked three ways**, so the gate cannot pass vacuously: it must fail, it must fail
*on `ENUM_VALUE_PREFIX`* (asserted against the JSON `type`, since buf's prose never names the rule),
and if the fixture is ever neutered the script reports the gate as vacuous rather than going green.
All three were exercised locally against buf 1.72.0.

### AC3 — baseline choice and the rules that actually fire

**Tip of `main`, not the merge base.** The task originally said merge base. The question the gate
answers is *"does what I am about to merge break what is already released"*, and `main` is what is
released — a merge base can be an old commit whose contracts nobody consumes, which would let a
break through whenever a branch is behind. CI passes `CONTRACTS_BASELINE` explicitly so it can never
compare a branch against itself, and `fetch-depth: 0` is required for the baseline to exist at all.

**The rule IDs were measured, not guessed.** Written against buf 1.72.0:

| Fixture mutation | Rule buf reports |
|---|---|
| additive field on an unused tag | *(none — accepted)* |
| field renumbered 2 → 5 | `FIELD_NO_DELETE` (tag 2 is gone; there is no "same number" rule) |
| field retyped `string` → `int32` | `FIELD_SAME_TYPE` |
| enum value renamed | `ENUM_VALUE_SAME_NAME` |

The first assertion written here guessed `FIELD_SAME_NUMBER` and the script's own
"failed, but not on the expected rule" branch caught it. That branch exists because a fixture with a
syntax error also "fails", and would otherwise be mistaken for a working gate.

**`ENUM_VALUE_SAME_NAME` is the rule that would have rejected AC2's rename.** That is why ADR-0032
sequenced the rename ahead of the baseline, and why the same change after this PR needs a superseding
ADR rather than a branch.

**Verified against the real contracts**, not only the fixtures: renumbering `event_id` in
`events/repository/v1/events.proto` fails the gate, adding `trace_id = 99` passes, and reverting
AC2's `CLOUD_GKE` → `GKE` fails on both `buf lint` and `buf breaking`.

### AC5 — why the original wording could not be built

AC5 asked for a codegen-freshness check **in each consumer's CI**. That is impossible today, and
`webfrontend`'s own workflow had already recorded the reason in a comment before this task started:
every consumer's `buf.gen.yaml` takes `../governance/contracts` as its input — a sibling checkout
that exists **only in the super-repo composition**. A standalone CI run in `backend`, `bff` or
`webfrontend` has no contracts to generate from, so a per-repo check could only ever be skipped or
faked.

Two ways out. Give every consumer its own pinned copy of the contracts, which is the
**generated-type publishing follow-up in ADR-0027/0028** — an open decision, and not one a task may
take. Or gate at the boundary where the composition actually exists. This task took the second:
`make codegen-check` in the super-repo regenerates all three consumers against the pinned
`contracts/` and fails on any difference.

What is lost by that choice, stated plainly: feedback arrives at the pin bump rather than in the
consumer's own PR, so a hand-edited `gen/` can merge into a consumer and is only caught when the
super-repo next composes it. Nothing reaches a released composition either way. The per-consumer
variant remains desirable and remains blocked on the ADR-0027/0028 decision.

`docs/process/ci-gates.md` carried this row as required in four repos for its whole life while no
such check existed anywhere. Its rows are now split to match what is enforceable — lint/breaking in
governance, generated-code freshness in the super-repo — so every ✓ in that table corresponds to a
check that runs.
