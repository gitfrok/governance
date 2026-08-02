# T-0009: Architecture fitness functions (extraction-readiness)

- **Status:** Done (2026-08-03)
- **Phase / Epic:** 0 / EP-0
- **Repo(s):** backend (AC1–AC3 module checks); super-repo if the AC4 trigger report is wired as
  an aggregate CI gate
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0026, 0025, 0022, **0030** (the budgets AC4 gates on)
- **Owner:** unassigned

## Goal
Continuously prove the monolith stays service-extractable, and track ADR-0026 triggers.

## Acceptance criteria (test-first)
- [x] AC1: Each module builds and its tests run in isolation (no sibling `internal/` deps).
- [x] AC2: The module dependency graph is acyclic; a cycle fails the build.
- [x] AC3: No module `api/` surface references an infra type (extends T-0002 AC4 fleet-wide).
- [x] AC4: A report emits the ADR-0026 trigger signals (per-module build/test time; fan-in/out)
  so extraction decisions are data-driven. Budgets agreed in **ADR-0030 (Accepted)**.

## Tests to write first
- boundary/arch: isolation build, acyclicity check, api-purity check.
- a reporting test/script that fails if a tracked trigger crosses its agreed budget.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `f38a3b3` (#4) | `internal/arch/graph.go` + `triggers.go`: AC1–AC4 |
| bff | `c496258` (#3) | `RuleDirectDataStore` — the rule T-0002 deferred here |
| super-repo | `2a6b60a` (#7) | `shellcheck` gated; `check-dep-direction.sh` word-splitting fixed |
| governance | `87e4e91` (#8) | docs-integrity CI; ADR-0030 |
| super-repo | `26078ac` (#9) | submodule pins bumped to the merged commits (invariant 24/25) |

Where T-0002 asks whether one file breaks a boundary, these ask whether the tree is still
separable into services — the property ADR-0026 depends on, and the one that erodes invisibly.

- **AC1** is transitive, which is the whole point: Go's `internal/` rule and T-0002 both catch the
  direct edge, but `A → shared helper → B/internal` compiles today and welds A and B into one
  binary forever. Failures print the whole chain.
- **AC3** closes the hole T-0002 AC4 recorded in its own notes — an `api/` file that is clean but
  re-exports through one that is not. It also catches generated gRPC stubs, which the direct check
  misses because the import path names this repo.
- The graph is built by parsing imports, not by invoking the toolchain, so it still answers on a
  tree that does not compile — the state a fitness function most needs to speak up in.
- Every check is asserted three ways, matching the T-0002 standard: it holds over the real tree, it
  fires on a fixture that breaks it, and it stays quiet on one that is merely unusual (a diamond,
  an adapter importing pgx, a module using its own internals).

## Notes / open questions
- **AC4's budgets are agreed: ADR-0030 is Accepted** (120s monolith build, 300s monolith test,
  fan-out 5). ADR-0026 trigger 4 referred to "an agreed budget" that had never been set, so the one
  trigger meant to fire mechanically could not; it now can. The numbers are deliberately loose —
  the tree is two modules and a sub-second build, and a budget that fires on ordinary Phase-1
  growth teaches people to raise it reflexively — and ADR-0030 schedules a revisit at Phase-1 exit.
- **PRD alignment.** §7 lists "service extraction without an ADR-0026 trigger" as a non-goal;
  AC4 is the only mechanism that makes that non-goal observable rather than aspirational.
- Deploy time is named in ADR-0026 trigger 4 and is **not** measured: nothing deploys yet.
- Fan-in is reported but not budgeted — high fan-in makes extraction expensive rather than
  overdue, so it belongs in the argument, not in a gate.
- Folded in from T-0002's notes, as that task directed: the bff `no direct DB access` rule, and
  `shellcheck` over `scripts/*.sh`. The latter was deferred over SC2086 from deliberate word
  splitting; that was fixed at the cause (NUL-delimited arrays) rather than suppressed, which also
  repaired a real bug — the old form silently skipped paths containing a space.
- Also added: governance had no CI at all. T-0002 called a docs/link check there "the obvious next
  gate for parity", and this repo is the one every other defers to (invariant 21).
