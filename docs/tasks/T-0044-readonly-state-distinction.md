# T-0044: PR-7 durability read-only vs envelope-throttle state distinction in UI/API

- **Status:** Done
- **Phase / Epic:** 3.1 / EP-23 (usage-view truth and the PR-7 distinction)
- **Repo(s):** backend (cause contract), webfrontend (rendering) — one commit per repo
- **Spec:** docs/specs/SPEC-0046-usage-view-pr7-distinction.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0061, 0018, 0008
- **Owner:** unassigned

## Goal

Every read-only state names its cause: the PR-7 durability mode (ADR-0018 — dual loss, audited
override) or an envelope-throttle effect — never a bare "read-only". Commercial states never render
as read-only; the prohibition SPEC-0041 AC8 has held since T-0034 gains the in-product distinction
the phase carried. This discharges the carry recorded in T-0034's exit ("AC8's product distinction
defers to PR-7", enforced per ADR-0061).

## Acceptance criteria (test-first)

SPEC-0046 AC4, plus AC5's pins on the surfaces this task touches:
- [x] AC4: any read-only state in the UI or API identifies its cause — the PR-7 durability mode
      (ADR-0018) or an envelope-throttle effect; commercial states never render read-only
      (SPEC-0041 AC8's prohibition, now with the distinction).
- [x] AC5 (on these surfaces): "not metered" never renders as zero, and git is never blocked in any
      envelope state — the regression pins cover the states this task labels.

## Tests to write first

Per SPEC-0046 § Test plan:
- backend: cause-carried read-only state — the API identifies the cause so every consumer renders
  the same distinction (cause labels are contract vocabulary, not UI copy).
- webfrontend vitest: state-cause rendering for every read-only surface — durability vs throttle vs
  never (AC4); "not metered" rendering.
- regression pins wired to fail the build (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- webfrontend: vitest suite plus build/typecheck.

## Notes / open questions

Sequenced last in M4 so the distinction renders against live envelope states, but it shares only the
epic with T-0043 — the API cause contract can land independently if needed. The PR-7 durability mode
itself is SPEC-0005/ADR-0018's; if PR-7's mode has no product state yet, AC4's durability branch
tests the API cause contract and the UI branch lands with PR-7's own work (SPEC-0046's assumption).
PR-7's own product work is not part of this task or this phase.

## Exit record (2026-08-16, Wave 5)

**Backend (0238dee, super-repo pin f5ec10f) — the API cause contract (SPEC-0046's assumption:
PR-7's mode has no product state yet, so the durability branch lands as the API cause contract):**
- `backend/modules/repository/api/readonly.go`: `ReadOnlyCause` contract vocabulary
  (`durability_mode` = PR-7/ADR-0018 dual loss, `envelope_throttle`) and `ReadOnlyState`, whose
  constructor REFUSES an unnamed cause — a bare "read-only" is not constructible.
  `ReadOnlyFromShard` maps only `ShardStateDegradedReadOnly` onto the durability cause; healthy
  and recovering shards stay writable conditions.
- AC4 durability branch: `TestReadOnlyFromShardNamesTheDurabilityCause`.
- AC4 bare-label prohibition: `TestBareReadOnlyIsNotExpressible`, `TestWritableConditionNamesNoCause`.
- AC4 commercial branch: `TestThrottleVocabularyCannotExpressReadOnly` (metering api) — the
  enforcement vocabulary has exactly three members and none expresses read-only, for every
  dimension; SPEC-0041 AC8's prohibition stays in force alongside `TestBreachThrottlesCIAndNeverGit`.
- Gates: gofmt/vet/build, arch fitness, full `-race` suite vs real Postgres — EXIT=0 (88
  packages), zero durability skips.

**Webfrontend (843a195, super-repo pin ea83e13):**
- `src/lib/readonlyCause.ts` mirrors the cause contract: durability and throttle render as
  DIFFERENT distinctions (durability names the audited override and keeps reads working);
  an absent/unknown cause renders nothing — no bare "read-only". `readOnlyFromEnvelopeState`
  encodes the commercial prohibition: WITHIN/NEAR/EXCEEDED never yield a read-only condition.
- AC4 rendering tests: `tests/readonly-cause.test.ts` (durability vs throttle vs never).
- AC5: the `never-read-only-from-commercial-state` pin joins the build-blocking `prebuild` set
  alongside the T-0043 never-zero/never-blocked-git pins — the pins cover the states this task
  labels.
- Gates: vitest 86/86, `tsc --noEmit`, `astro build` (pins included).

**Super-repo:** `make verify` + `make codegen-check` + `make surfaces-check` green at ea83e13.

**Honest carries:**
- The proto/contract half of the cause vocabulary lands with PR-7's own product state (SPEC-0046's
  assumption): no existing view contract carries a read-only field today, so there is no additive
  governance PR to make yet. The backend api vocabulary and the webfrontend mirror are the
  distinction consumers render from; the wire shape is additive-only work when PR-7 lands.
- No product UI surface displays a repository read-only state yet; the rendering branch the
  vitest suite proves is the distinction module itself. Wiring it onto a live repository page
  belongs to PR-7's product work.
- EP-23 completes with this task (T-0043 + T-0044 both Done).
