# T-0091: A gate that refuses an inherited cluster location

- **Status:** Todo
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

- [ ] AC1 A `live/*/gke/terragrunt.hcl` with no `location` in `inputs` is refused, naming the unit.
- [ ] AC2 A **zone** and a **region** are both accepted — the gate asserts explicitness, never a
      value.
- [ ] AC3 A commented-out `location` is refused.
- [ ] AC4 Each negative fixture refused **for its own reason**, read from the violation text.
- [ ] AC5 The two shipped units accepted in the same run.
- [ ] AC6 Wired into `make verify`; offline, no GCP credentials.
- [ ] AC7 `deploy/gcp/README.md` says the gate exists and what it deliberately does not assert.

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
