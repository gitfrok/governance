# T-0091: A gate that refuses an inherited cluster location

- **Status:** Done (2026-09-22) — super-repo@02dc44d; AC1–AC7 met
- **Phase / Epic:** first control-plane deployment (ADR-0106 carry)
- **Repo(s):** **super-repo** only (`scripts/`, `deploy/gcp/README.md`). No `backend`, `bff`,
  `webfrontend` or `governance` change is in scope — invariant 23.
- **Spec:** `../specs/SPEC-0072-the-cluster-location-is-declared.md` (AC1–AC7)
- **ADRs:** 0106 (Accepted 2026-09-22 — decisions 1 and 2; the "no gate enforces it" consequence is
  the whole task), 0092 (the units), 0001
- **Owner:** unassigned

## Goal

Make an omitted `location` fail loudly in CI instead of quietly tripling an environment's node bill
a month later.

## Acceptance criteria (test-first)

- [x] AC1 A `live/*/gke/terragrunt.hcl` with no `location` in `inputs` is refused, naming the unit.
- [x] AC2 A **zone** and a **region** are both accepted — the gate asserts explicitness, never a
      value.
- [x] AC3 A commented-out `location` is refused.
- [x] AC4 Each negative fixture refused **for its own reason**, read from the violation text.
- [x] AC5 The two shipped units accepted in the same run.
- [x] AC6 Wired into `make verify`; offline, no GCP credentials.
- [x] AC7 `deploy/gcp/README.md` says the gate exists and what it deliberately does not assert.

## Tests to write first

- **AC2 before AC1.** Writing the refusal first invites the cheapest implementation that satisfies
  it — a grep for `asia-southeast1-a` — which passes today and refuses ADR-0106 decision 2's own
  reversal path. The region-accepted case is what forbids that, so it goes in first and must be seen
  to **fail** against a value-matching stub.
- **fixtures, nested so each produces one violation.** T-0090's exit record is the precedent and the
  warning: three fixtures there were refused by a directory-name rule *before the rule under test
  existed*, and `expect_refusal` read only the exit status, so they looked like proof for a day.
  Assert the violation **text**.
- **AC3 as its own fixture.** A commented-out line is not a variant of a missing one for a human
  reading a diff, which is exactly why it needs its own named refusal.
- **a control test for AC1** — the same fixture with `location` restored is **accepted**. "This is
  refused" means nothing without it; that pairing is the standard this tree now holds gates to.

## Definition of Done

See `../process/definition-of-done.md`. Plus: `make verify` green in the super-repo, and one commit
in the super-repo only (invariant 23).

## Notes / open questions

**Do not assert the value.** SPEC-0072's out-of-scope section is the decision, not a preference.
ADR-0106 decision 2 expects the zonal choice to be revisited when an availability requirement is
stated, and a gate pinning the zone would make that reversal a gate fight instead of a one-line edit.
The model is `check-platform-kustomize.sh` AC10: `storageClassName` must be **stated**, and the gate
has no opinion on which.

**If a unit ever computes `location`**, SPEC-0072 says to report it and choose deliberately —
teach the gate to evaluate, or refuse computed locations — rather than loosening AC1 until it passes.

**Discover the units, do not list them.** A hard-coded list of two environments is a gate that is
silently wrong on the day a third is created, which is precisely when it is most needed.

## Exit record (2026-09-22, super-repo@02dc44d)

All seven criteria met. `make verify` exit 0, with the gate and its failability proof running beside
each other as the other two pairs do.

**The stub was written on purpose, and it is the finding.** Before the real gate, the cheapest
implementation satisfying AC1 — `grep -q 'asia-southeast1-a'` — was written and the suite run
against it. It **passed `missing-location`** and **passed both live units**. The only thing that
caught it was `regional`:

| Fixture | Against the stub |
|---|---|
| `missing-location` | refused — **stub looks correct** |
| the two shipped units | accepted — **stub looks correct** |
| `zonal` | accepted — **stub looks correct** |
| `regional` | **REFUSED — over-fires on ADR-0106 decision 2's own reversal path** |
| `commented-location`, `nested-only` | accepted — stub is blind |

A suite written from the refusals alone would have shipped that stub, and the failure would have
surfaced the day somebody tried to restore regional under an availability requirement — the worst
possible moment. This is why AC2 went in first.

**Three mutations, each caught by exactly the fixture aimed at it**, so no assertion is carried by
another:

| Mutation | Models | Result |
|---|---|---|
| `declares_location` returns True | a gate that asserts nothing | FAIL ×3 — `missing-location`, `commented-location`, `nested-only` |
| `strip_comments` is a no-op | AC3 regressing | FAIL — `commented-location` only |
| depth check removed | a flat text match | FAIL — `nested-only` only |

**Proven against the real tree, not only fixtures.** Both live units were copied verbatim
(accepted), then the single line `location = "asia-southeast1-a"` was deleted from prod-cp's copy —
refused, naming the unit, with the violation stating the per-zone multiplication. That is the exact
edit ADR-0106 warns looks like tidying.

**The harness reads violation TEXT, not exit status**, and `expect_refusal` takes the substring each
refusal must contain. T-0090's exit record is why: three fixtures there were refused by an unrelated
rule firing on their own directory name, and a status-only assertion called it proof for a day.

**`nested-only` is not in SPEC-0072's AC list and was added anyway.** A `location` inside
`system_pool` is not an input to the module, so accepting it would satisfy AC1's letter while
leaving the cluster regional. It is recorded as AC1 rather than smuggled in as a new criterion.

**One finding outside this task's scope: `make lint-shell` does not pass, and did not before this
change.** Verified by stashing: `shellcheck scripts/*.sh` exits 1 on the pre-existing tree.
`check-byo-chart.sh` carries SC2015 and `check-controlplane-kustomize.sh` / `check-platform-kustomize.sh`
carry **SC2259 (error)** — a heredoc overriding piped input on the `find | xargs python3` lines. Both
new scripts here are shellcheck-clean. Not fixed: SC2259 is about how those gates feed `python3`, so
a fix changes their behaviour and needs its own task and its own proof. The Makefile says CI gates
`lint-shell` on every PR, which is worth reconciling with the fact that it is currently red.
