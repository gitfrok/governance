# T-0043: Usage-view divergence health gates and envelope-state telemetry through bff → webfrontend

- **Status:** Done — **blocked-by T-0035 resolved** (T-0035 Done: backend@a9ed620 applied the
  envelope throttle in the data plane, making AC3 testable and claimable)
- **Phase / Epic:** 3.1 / EP-23 (usage-view truth and the PR-7 distinction)
- **Repo(s):** backend, bff, webfrontend — ADR-0027 order, one commit per repo
- **Spec:** docs/specs/SPEC-0046-usage-view-pr7-distinction.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0061, 0018, 0008
- **Owner:** unassigned

## Goal

Make PR-23's view tell the truth end to end: divergence between control-plane-derived telemetry and a
data plane's own report surfaces as a health finding with both numbers shown, near-envelope and
exceeded states are visible per dimension before enforcement acts, and the **applied** throttle —
not merely the delivered one — is observable from backend through bff to the customer's browser.

## Acceptance criteria (test-first)

SPEC-0046 AC1, AC2, AC3, AC5 (AC4 is T-0044's):
- [x] AC1: a divergence between control-plane telemetry and a data plane's own report surfaces as a
      health finding in the usage view, with both numbers shown — it never adjusts a metered number;
      the finding is the product, not an input (SPEC-0041 AC1's rule, rendered where the customer
      looks).
- [x] AC2: near-envelope and exceeded states are visible to the customer per dimension, before
      enforcement acts — the state names its dimension, its trend and which envelope behaviour
      follows (SPEC-0041 AC4's notification is not the customer's first sight of trouble).
- [x] AC3: throttle application is observable end-to-end — telemetry reflects the applied throttle in
      the customer's cluster. **Untestable and not claimable until T-0035 lands.** (T-0035 landed;
      claimed below with its exit-record carries.)
- [x] AC5: unmetered dimensions render "not metered", never zero, and git is never blocked in any
      envelope state — regression pins wired to fail the build if either regresses (SPEC-0041 AC2/AC7).

## Tests to write first

Per SPEC-0046 § Test plan:
- backend: divergence-finding derivation with both numbers preserved (AC1); per-dimension
  near/exceeded state computation ahead of enforcement (AC2); applied-throttle reflection once T-0035
  lands (AC3).
- bff: nil-gap propagation — a gap or "not metered" marker must survive aggregation and never
  collapse to zero on its way to the browser (AC5).
- webfrontend vitest: per-dimension envelope states and "not metered" rendering (AC2, AC5).
- regression pins: never-zero for unmetered dimensions, never-blocked git per dimension (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- bff: `gofmt` / `go build` / `go vet`, boundary/arch fitness, `go test` — aggregation only, no
  business logic.
- webfrontend: vitest suite plus build/typecheck.

## Notes / open questions

Where a cause or state field the ACs need is missing from an existing view contract, the additive
change goes first under its own governance PR (SPEC-0046 Contracts touched). The view renders from
the same counters envelope decisions were made from (SPEC-0041 AC10) — no second internal number.
If T-0035's chosen mechanism does not report enough applied-state fact for AC3, that gap is T-0035's
exit record to carry, not a reason to weaken the AC (SPEC-0046's assumption).

## Exit record (2026-08-16, Wave 5)

**Contract (governance-first, additive-only):** trend half landed first (usage/v1 `EnvelopeTrend` +
`UsageDimensionView.trend` field 13, governance@b425db0); AC3's shape landed the same route
(`EnvelopeThrottleObservation` + `GetUsageViewResponse.envelope_throttle` field 4, governance@36f284b,
SPEC-0046 Contracts-touched updated in the same commit). Consumer regen one commit per consumer
(backend@a25598b, bff@34d264a, webfrontend@92ba712) and the super-repo pin bump immediately after
(14781db). No field renumbered.

**Backend (bc30abd, super-repo pin 652fe6c):**
- AC1: divergence carries BOTH numbers and never adjusts the counter —
  `TestSelfReportIsOperationalInputNeverCounter` / `TestAgreeingSelfReportRecordsNothing`
  (T-0034, still green) + wire mapping in `TestGetUsageViewMapsDerivedCounter`.
- AC2: `TestUsageViewNamesNearStateAndTrendBeforeBreach` — the NEAR row names dimension, state and
  trend with the SAME derivation the AC4 notice cites (`trendOf`), and the view trend equals the
  notice trend; NEAR warns without throttling. Wire level: trend maps only on metered, non-gap rows
  (`TestGetUsageViewMapsDerivedCounter`).
- AC3: `TestThrottleObservationEndToEnd` — absent before any evaluation; the metered half
  (generation, max CI concurrency 2, queue depth cap 50) after breach; the applied half absent
  until an ack; a failed ack cited with its error prose. Wire level:
  `TestGetUsageViewMapsEnvelopeThrottleObservation`.
- AC5 backend half: SPEC-0041 AC7's per-dimension discipline stays in force
  (`TestBreachThrottlesCIAndNeverGit`).
- Gates: gofmt/vet/build, arch fitness, full `-race` suite vs real Postgres — EXIT=0, zero
  durability skips.

**Bff (4059a23, super-repo pin 6dc3dc3):** trend travels only alongside a number;
`TestGetUsageViewShapesThrottleObservation` (absent → metered half → failed ack cited) and
`TestUsageViewThrottleObservationJSON` (the JSON omits the throttle key until present, and the
applied half until acked — a failed ack marshals `"applied":false` with its prose). Nil-gap
propagation (AC5): `TestGetUsageViewShapesCoverageAndGaps` — a gap or "not metered" marker survives
aggregation with nil numbers and no trend, never collapsing to zero. Gates: gofmt/vet/build + full
`go test` green.

**Webfrontend (08f42c4, super-repo pin f2edaa1):** a state badge names its trend and which
envelope behaviour follows (`envelopeBehaviour` prose, NEAR/EXCEEDED tested); the throttle
observation renders its metered and applied halves separately (unacked / applied / failed-ack
rendering all tested); everything rendered, never derived. AC5 pins:
`tests/usage-regression-pins.test.ts` (never-zero for unmetered dimensions; never-blocked git per
dimension × state) wired into `npm run build` via `prebuild` — a regression fails the build.
Gates: vitest 81/81, `tsc --noEmit`, `astro build` (pins included).

**Super-repo:** `make verify` + `make codegen-check` + `make surfaces-check` green at f2edaa1.

**Honest carries:**
- AC3's live-cluster half (telemetry reflecting the APPLIED throttle in a real customer cluster)
  rides the ack path proven here; the browser/cluster proof lands with board task #22's E2E lane.
  **Record correction (2026-08-16, board #23):** the earlier authenticated browser E2E claims from
  that lane were invalid and are retracted here. What was actually proven = the UNAUTHENTICATED
  graceful-degradation and never-zero rendering at localhost:4321, evidenced by the screenshots in
  `webfrontend/test-results/t22-verify-{1-home,2-usage-degraded,3-readonly-surface-gate}.png`.
  The live AUTHENTICATED usage path is not provable in the current dev posture until all of:
  (a) the bff has `GITFROK_USAGE_ADDR` pointed at a controlplane running a real usage service;
  (b) a tenant exists carrying metered usage data; (c) the OIDC app is provisioned and DNS is wired.
  Until then, no authenticated E2E claim may be made for this surface.
- Trend honesty: with a single interval the past is unknown, so the service path renders FLAT —
  the same derivation the notices cite, never an estimate. Rising/falling appears once a prior
  interval exists; the derivation and its parity are what the tests pin.
- Dependabot advisories on the consumer repos' default branches are pre-existing dependency noise,
  untouched by this task.
