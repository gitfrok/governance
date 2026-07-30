# T-0002: Boundary/arch enforcement in CI

- **Status:** In review (AC1–AC4 done and CI-green; AC5 partially — see below)
- **Phase / Epic:** 0 / EP-0
- **Repo(s):** backend + bff (each repo's own arch tests + CI; AC3 is a bff rule) + super-repo
  (composition gates: the `check-dep-direction.sh` fix and the super-repo CI workflow)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0022, 0025, 0026, 0027
- **Owner:** unassigned

## Goal
Machine-enforce invariants 14–18 so coupling cannot regress.

## Acceptance criteria (test-first)
- [x] AC1: A `module/internal/domain` package importing infra (pg/redpanda/http/opa/zitadel) fails the build.
- [x] AC2: A module importing another module's `internal/*` fails the build (cross-module only via `api/` or the bus).
- [x] AC3: The BFF importing any module's `internal/*` fails the build (aggregation only).
- [x] AC4: A module's `api/` package exposing an infra type (pg/http/redpanda/…) fails the build.
- [ ] AC5: CI runs these on every PR and blocks merge on violation.
      **Runs** — yes, on all three repos. **Blocks** — not yet; see "Remaining for AC5".

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
- **`shellcheck` over `scripts/*.sh` is not gated.** Those scripts rely on intentional word
  splitting (`grep ... $files` → SC2086) and need targeted disables first. Candidate for T-0009.
- **`no direct DB access`** (bff `AGENTS.md`) is the same mechanism as these rules but outside this
  task's criteria — fold into T-0009 rather than widening T-0002.

## Remaining for AC5
Branch protection exists on all five repos (`main`: 1 required approving review, stale-review
dismissal, conversation resolution, no force-push, no deletion) with required status checks
`build + vet + arch gates` (backend, bff) and `super-repo fitness gates` (super-repo). It does
**not** yet block, because `enforce_admins=false`: a repo admin's `git push origin main` succeeds
even though GitHub prints "Changes must be made through a pull request", and `gh pr merge --admin`
bypasses the review gate. Verified empirically.

Closing AC5 needs `enforce_admins=true`. That cannot be set while the org has a single member —
GitHub forbids self-approval, so a required review plus bound admins makes merging impossible.
**Decision taken:** add a second org member who can approve, keep the review requirement, then bind
admins. Until then AC5 stays open and this task stays In review.

`governance` and `webfrontend` have no CI, so they gate on review only. `governance` is the Source
of Truth; a docs/link check there is the obvious next gate for parity.
