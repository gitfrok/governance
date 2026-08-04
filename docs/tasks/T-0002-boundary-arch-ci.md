# T-0002: Boundary/arch enforcement in CI

- **Status:** Done (AC1–AC5; AC5 enforcement verified empirically — see "AC5 as closed")
- **Phase / Epic:** 0 / EP-0
- **Repo(s):** backend + bff (each repo's own arch tests + CI; AC3 is a bff rule) + super-repo
  (composition gates: the `check-dep-direction.sh` fix and the super-repo CI workflow)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0022, 0025, 0026, 0027, 0031 (AC5 enforcement)
- **Owner:** unassigned

## Goal
Machine-enforce invariants 14–18 so coupling cannot regress.

## Acceptance criteria (test-first)
- [x] AC1: A `module/internal/domain` package importing infra (pg/redpanda/http/opa/zitadel) fails the build.
- [x] AC2: A module importing another module's `internal/*` fails the build (cross-module only via `api/` or the bus).
- [x] AC3: The BFF importing any module's `internal/*` fails the build (aggregation only).
- [x] AC4: A module's `api/` package exposing an infra type (pg/http/redpanda/…) fails the build.
- [x] AC5: CI runs these on every PR and blocks merge on violation.
      **Runs** — yes, on all three repos. **Blocks** — yes, since ADR-0031; see "AC5 as closed".

## Tests to write first
- boundary/arch tests (go-arch-lint or import-linter equivalent) with fixtures that
  intentionally violate each rule and must be caught.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Merged | What |
|---|---|---|
| backend | `ff8ab47` (#2) | `RuleDomainImportsInfra` (AC1), `RuleCrossModuleInternal` (AC2), `RuleAPIExposesInfra` (AC4, new); per-rule fixtures; `.github/workflows/ci.yml` |
| bff | `87df91f` (#2) | `RuleBackendInternalImport` (AC3) + `RuleBackendImport`; fixtures; `.github/workflows/ci.yml` |
| super-repo | `8385472` (#4), `1f0b066` (#5) | `check-dep-direction.sh` import-spec fix; super-repo CI running `make verify` + `make bootstrap` |
| governance | `ffdb7ab` (#10) | ADR-0031 Accepted — the AC5 enforcement decision |
| super-repo | `07f9250` (#11) | `scripts/apply-rulesets.sh` (`plan`/`apply`/`check`) + `make rulesets*`; applied to all five repos, legacy protection deleted |

Each checker has three test layers so a gate cannot pass vacuously: a scan over real source,
per-rule fixtures proving every forbidden edge is caught, and positive fixtures proving legitimate
code is not blocked. Every gate was also verified against a **real in-tree violation**, not only
fixtures.

## Notes / open questions
- **AC4 is import-level, not type-level.** A type can only appear in an exported signature if its
  package is imported, so import purity is what keeps an `api/` surface infra-free (invariant 20,
  ADR-0026). A signature could still leak an infra type re-exported through an intermediate package
  via a type alias. Cheap to add in the T-0009 family if it ever shows up.
- **The bff rule is deliberately wider than AC3's wording.** AC3 names a module's `internal/*`;
  `RuleBackendImport` bans importing the backend module at all, because a module's `api/` is an
  *in-process* surface and the only cross-repo surface is `contracts/` (invariant 22, ADR-0027).
  Enforcing the literal wording would have left the real hole open.
- **AC2/AC3 are partly compiler-enforced already** by Go's own `internal/` visibility rule. The arch
  tests add a clear failure message and catch the edge before a build; they are not the sole
  enforcement. AC1 and AC4 are the genuinely new gates.
- **`check-dep-direction.sh` had a false positive** the moment this task landed: it grepped for any
  occurrence of a forbidden module path, and bff's own checker must name
  `"github.com/gitfrok/backend"` in a string constant to enforce against it. Now matches import
  specs only; re-verified that aliased, single-line and named-alias imports all still fail.
- **`shellcheck` over `scripts/*.sh` was not gated** when this task landed: the scripts relied on
  intentional word splitting (`grep ... $files` → SC2086). T-0009 replaced that with NUL-delimited
  arrays and `make lint-shell` now gates it, with no suppressions to maintain — which is also what
  made the AC5 red-check probe above possible.
- **`no direct DB access`** (bff `AGENTS.md`) is the same mechanism as these rules but outside this
  task's criteria — fold into T-0009 rather than widening T-0002.

## AC5 as closed

**How it was blocked.** Legacy branch protection existed on all five repos but had
`enforce_admins=false`, and legacy protection has a *single* admin-binding switch covering every one
of its rules. Turning it on would have bound the required review too, and GitHub forbids
self-approval — so with one org member `main` would have become unmergeable. The earlier decision
recorded here was "add a second org member first", which parked a code-quality gate behind an org
action.

**How it was closed — ADR-0031 (Accepted).** Rulesets carry a bypass list *per ruleset*, and AC5 asks
for *checks* to block, not for review. `main` now carries two rulesets in every repo:

| Ruleset | Rules | Bypass actors |
|---|---|---|
| `main-integrity` | PR required (0 approvals), required status checks, no force-push, no deletion, threads resolved | **none** |
| `main-review` | 1 approving review, dismiss stale | admins, until the org has a second member |

Legacy protection was deleted rather than left alongside: overlapping rules union and the loosest
bypass wins. Applied by `scripts/apply-rulesets.sh` in the super-repo (`plan`/`apply`/`check`), whose
`check` mode fails on drift — its first assertion is that `main-integrity` has zero bypass actors,
because one entry there re-opens this criterion.

**Verified empirically on 2026-08-04**, both against the super-repo:

| Probe | Result |
|---|---|
| `git push origin main` (admin, direct) | `! [remote rejected] main -> main (push declined due to repository rule violations)` — "Changes must be made through a pull request" / `Required status check "super-repo fitness gates" is expected`. The same push **succeeded** under legacy protection. |
| `gh pr merge --admin --squash` on a red required check (PR #12, a deliberate SC2086 failing `make lint-shell`) | `GraphQL: Repository rule violations found — Required status check "super-repo fitness gates" is failing`. Closed unmerged. |

Required checks now enforced: `super-repo fitness gates` (super-repo), `build + vet + arch gates`
(backend, bff), `docs gates` (governance — running since T-0009 but never required until now).

**What is deliberately still open**, tracked in ADR-0031, not here:
- `webfrontend` has no workflow, so it gets `main-integrity` without a required check — the CI-free
  rules (PR-only, no force-push, no deletion) still apply. `ci-gates.md` wants lint/unit/E2E/arch there.
- No four-eyes review on `main` while the org has one member: `main-review` is admin-bypassable, so a
  solo admin can self-merge a green PR. Adding a second member and dropping that bypass is the
  follow-up. This is a review gap, not a *checks* gap — AC5 is about the latter.
- Org-level rulesets need GitHub Team, so the two rulesets are five per-repo copies;
  `make rulesets-check` is what keeps them from drifting.
