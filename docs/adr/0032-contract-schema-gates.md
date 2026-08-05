# ADR-0032: Gate the contract schema — lint and breaking-change checks on `contracts/`

- **Status:** Accepted
- **Date:** 2026-08-06 (proposed and accepted the same day)
- **Deciders:** platform
- **Governs:** G7 process integrity (the shared surface cannot regress unnoticed)
- **Relates to:** ADR-0022 (contracts are the only shared surface), ADR-0027 (cross-repo order),
  ADR-0031 (required checks bind admins) · **Invariants:** 10, 21, 22, 24 ·
  **Tasks:** T-0020 (implements this) · **Process:** `../process/ci-gates.md`

## Context

`docs/process/ci-gates.md` marks **"contract schema (additive / breaking-check)"** as a *required*
check in four repos — `governance`, `backend`, `bff`, and `webfrontend` (TS gen). No such check
exists. `buf` appears in no CI workflow in any of the five repos; the only trace is a commented-out
TODO in `webfrontend/.github/workflows/ci.yml`. The declared gate has never run.

It is also **red**. Run on 2026-08-06 against `contracts/` with buf 1.72.0:

- `buf build` — OK, the module is valid.
- `buf lint` — **13 violations**, every one `ENUM_VALUE_PREFIX`, all in
  `proto/agent/v1/agent.proto`, across three enums:

  | Enum | Values buf rejects | Prefix buf wants |
  |---|---|---|
  | `Cloud` | `GKE`, `EKS`, `AKS`, `OTHER` | `CLOUD_` |
  | `HealthState` | `HEALTH_UNSPECIFIED`, `HEALTHY`, `DEGRADED`, `UNHEALTHY` | `HEALTH_STATE_` |
  | `CommandType` | `COMMAND_UNSPECIFIED`, `TRIGGER_RECONCILE`, `ROTATE_CLIENT_CERT`, `DRAIN_RUNNERS`, `COLLECT_DIAGNOSTICS` | `COMMAND_TYPE_` |

`contracts/buf.yaml` selects `lint.use: STANDARD` and excepts five rules; `ENUM_VALUE_PREFIX` is not
among them. Its own comment defers the policy to "governance's own CI gate" — the gate this ADR
exists to create. So the SoT declares a lint policy it does not meet and does not enforce.

Two facts bound the cost of fixing it now rather than later:

1. **Nothing implements the agent protocol.** It is Phase-3 work (ADR-0011, ADR-0017); no agent is
   deployed, and no persisted data or wire traffic carries these names. The only hand-written
   references are three codegen smoke lines — `backend/cmd/controlplane-app/main.go`,
   `backend/cmd/dataplane-app/main.go`, `bff/cmd/bff/main.go` — each a discarded `_ =` assignment.
2. **Codegen is reproducible.** Regenerating Go into `backend/gen` and TS into `webfrontend/src/gen`
   from `contracts/` on 2026-08-05 produced output byte-identical to what is committed. A
   codegen-freshness check would pass on all three consumers the day it is switched on.

Renaming an enum *value* leaves its number and type untouched, so invariant 10 — "never change/reuse
field numbers or types; reserve removed tags; enums keep `*_UNSPECIFIED = 0`" — does not forbid it.
It does change the JSON/text encoding, which `buf breaking` flags under `FILE`. That is the real
tension: the rename is *compatible enough* to be safe today and *incompatible enough* that the gate
we are adding would reject it tomorrow. Whichever way it resolves, it must resolve **before** the
breaking baseline is set, because the baseline is what makes the choice permanent.

## Decision

We will **wire the contract-schema gate, and rename the 13 enum values first**, so the baseline is
set on a tree that satisfies the policy we claim to hold.

1. **`buf lint` and `buf breaking` become required checks on `governance`**, added to its existing
   `docs gates` workflow. `buf breaking` runs `--against` the merge base with `main`.
2. **The 13 enum values are renamed** to the prefixes `ENUM_VALUE_PREFIX` requires, together with
   the three `_ =` references in `backend` and `bff`, in ADR-0027 order (governance PR first, then
   each consumer, then the super-repo pin bump). This is a **one-time, pre-baseline** correction of
   an unimplemented surface — not a licence to break v1 later.
3. **The breaking baseline starts after the rename.** From the merge of T-0020 onward, every change
   to `contracts/` is checked against `main`, and `FILE` is the category — the strictest, matching
   the additive-only rule in `contracts/README.md`.
4. **No new lint exceptions.** `contracts/buf.yaml` keeps its five existing excepts, which are
   ADR-backed shape choices; `ENUM_VALUE_PREFIX` is not added to them.
5. **Consumers gate codegen freshness**, satisfying the `ci-gates.md` row for `backend`, `bff` and
   `webfrontend`: regenerate from the pinned `contracts/` and fail on a non-empty `git diff`. This
   catches the drift the pin bump is supposed to prevent — a consumer whose `gen/` no longer matches
   the contracts it pins.

## Consequences

**Positive:** the declared gate exists and is green rather than declared and red. The `v1` agent
surface becomes idiomatic while it is still free to change — after Phase 3 it would not be. Lint
policy stays uniform, with no per-file exemption for a future reader to discover. Codegen drift
becomes impossible to merge.

**Negative / costs:** one cross-repo change (governance → backend, bff → super-repo pin) for a
protocol nobody uses yet, spending ADR-0027 ceremony on three throwaway lines. Anyone holding a
branch that references the old names must rebase. `buf breaking` needs the merge base fetched in CI
(`fetch-depth: 0`), which slows checkout on the SoT repo slightly.

**Follow-ups:** none of the five existing `buf.yaml` excepts is re-examined here — they predate this
ADR and each is justified in the file; revisit only if a contract change trips one. `buf format` is
deliberately not gated.

## Alternatives considered

- **Grandfather the file** (`lint.ignore_only.ENUM_VALUE_PREFIX: [proto/agent/v1/agent.proto]`),
  gate everything else — the conservative option, and the right one if the deciders read invariant
  10 as protecting names as well as numbers. Rejected as the default because the exemption is
  permanent for a surface that has no users today, and every future reader of `agent.proto` inherits
  a naming style the linter says is wrong. It was carried as the fallback through review and
  **not taken**; it would have changed only step 2, leaving steps 1 and 3–5 intact.
- **Blanket-except `ENUM_VALUE_PREFIX`** alongside the existing five — rejected: it silently exempts
  every contract we have not written yet, which is the opposite of what a gate is for.
- **Rename and keep a deprecated alias** — not expressible: proto3 `allow_alias` shares a *number*
  between two names, so the old names would remain in the generated API forever, which is the cost
  we are trying to avoid.
- **Leave the gate unwired and fix `ci-gates.md` to stop claiming it** — rejected: the claim is
  correct and the gap is real. A shared surface with no schema check is exactly the coupling risk
  ADR-0022 exists to prevent.
- **Gate `buf breaking` only, skip lint** — rejected: breaking-checks freeze whatever shape exists,
  so skipping lint would freeze the 13 violations permanently and make the fallback unavailable.
