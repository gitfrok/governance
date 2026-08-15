# T-0034: Fair-use metering, envelopes, and the usage view

- **Status:** Done (2026-08-15) — governance@5dff9b3, backend@d3f4ad6, bff@e2344de,
  webfrontend@95f77be+0e80261; SPEC-0041 AC1–AC10 proven per ADR-0061; recorded limits below
- **Phase / Epic:** 3 / EP-18 (commercial)
- **Repo(s):** governance (additive telemetry/envelope messages), backend, bff, webfrontend — ADR-0027
  order, one commit per repo
- **Spec:** docs/specs/SPEC-0041-fair-use-metering.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0061, 0008, 0018, 0011, 0017
- **Owner:** unassigned

## Goal
Meter usage centrally, show it before an envelope is reached, and enforce by throttling — with git
untouched in every state.

## Acceptance criteria (test-first)
SPEC-0041 AC1–AC10. The two that must not be softened:
- [x] AC7: git push, fetch, clone and reads succeed under a breach of **every** dimension — one test
      per dimension, because this is the promise a well-meaning throttle breaks first.
- [x] AC8: no repository is ever made read-only for a commercial reason; the durability read-only
      mode (ADR-0018) stays distinguishable in the product.
- [x] AC2: every deferred dimension reads as "not metered", never as zero or within-envelope.

## Tests to write first
- unit: counter derivation from telemetry; restart without double-count or lost interval; gap
  rendering for a silent data plane.
- integration: threshold notice before breach; CI concurrency reduction with queued jobs delayed and
  visibly caused, never dropped.
- product: the git-availability matrix (AC7) and the read-only distinction (AC8).

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony.

## Notes / open questions
Repository storage and index size are sizes, not events, and are the likeliest AC2 deferrals — decide
that before building the view, so it never implies coverage it lacks. Prices and tiers stay out
(ADR-0008 follow-up); nothing here bills.

## Exit record (2026-08-15)

Implemented test-first and merged across four repos, ADR-0027 order: governance main at **5dff9b3**
(additive `UsageSample` fields 7–10, `FairUseDimension`/`EnvelopeState` enums, envelope update/ack
messages, and the **new** `usage/v1/usage.proto` `UsageService.GetUsageView`, with `usage.view.read`
granted to owner+member), backend main at **d3f4ad6**, bff main at **e2344de**, webfrontend main at
**95f77be** + **0e80261**.

**SPEC-0041 AC1–AC10, one line of proof each (per ADR-0061):**

- **AC1** — counters derive in the control plane from received telemetry; a data plane's reported
  totals never change a counter, and a divergence is a health finding with **both** numbers shown,
  not an adjustment.
- **AC2** — every deferred dimension reads as "not metered", never as zero or within-envelope;
  coverage is explicit in both the spec and the view.
- **AC3** — missing telemetry renders as a gap over the affected interval, never as zero — and the
  gap survives the whole backend→bff→web chain, so a disconnected data plane is visible in the
  customer's own view.
- **AC4** — crossing a notification threshold produces an in-product notice naming the dimension and
  its trend **before** the envelope is reached, not on breach.
- **AC5** — envelope exceeded on a CI dimension reduces job concurrency and caps queue depth; running
  jobs finish, queued jobs are delayed and never dropped, and the delay is visible as a cause.
- **AC6** — envelope exceeded on a storage/index dimension warns and reports and may throttle new
  large-object writes; nothing already stored becomes unreadable.
- **AC7** — git stays available in every envelope state: push, fetch, clone and reads succeed under a
  breach of every dimension, one test per dimension. Throttling is CI concurrency/queue caps only —
  git is never blocked, structurally.
- **AC8** — no repository is ever made read-only for a commercial reason (the enforcement path cannot
  produce it); read-only stays reserved for the PR-7 durability mode (ADR-0018). *The product
  distinction between the two states is enforced when PR-7 lands — see recorded limits.*
- **AC9** — **partially met, and carried.** Envelope state is computed centrally, published as
  desired state over the agent channel, and the gateway handles its ack; the control plane never
  reaches into the cluster. What does not exist is the data-plane half: the shipped agent client
  (`platform/agentclient`) ignores `DesiredState`/`EnvelopeStateUpdate` by comment, nothing in the CI
  runtime reads `MaxCIConcurrency` or `QueueDepthCap`, and the only `EnvelopeStateAck` producer is
  the gateway's integration-test client. So AC5's behaviour — running jobs finishing while queued
  jobs are delayed and visibly caused — does not happen in a customer's cluster. Carried as
  **T-0035**; found by the phase-3 review (H2), which also noted this line previously read as met.
  **Correction (2026-08-16): the carry is discharged.** T-0035 is Done — backend **a9ed620**,
  pin-bumped by super-repo **9f526d0** — so the "what does not exist" sentence above describes the
  backend pinned when this record was written, not the tree: `platform/agentclient` now applies each
  update through `EnvelopeSink.ApplyEnvelopeCaps` and emits a real `EnvelopeStateAck`, and the CI
  dispatcher binds `MaxCIConcurrency` as a hard in-flight bound with `QueueDepthCap` on the gauge
  KEDA reads. The sentence stands as dated history; this correction binds. What AC9 still owes is the
  cluster-lane demonstration, not the code.
- **AC10** — the customer and the platform read the same counters: the usage view reads the same
  ledger the envelope decision was made from, tenant-isolated; no second internal number.

**Recorded limits:**

- **The envelope throttle is computed but not applied.** See AC9 above: central computation,
  delivery and the ack surface exist; no data-plane consumer does. The reason it is a task rather
  than a wiring fix is that the CI dispatcher claims at most one job per tick and scales by KEDA
  replicas, so a per-tenant concurrency cap has nowhere to land yet — where the cap binds (claim
  gate, scaler input, or both) is a design decision T-0035 owns.
- **AC8's product distinction defers to PR-7.** The read-only-for-commercial prohibition holds now
  (nothing can produce it), but the in-product distinction from the PR-7 durability read-only mode
  (ADR-0018) is enforced per ADR-0061 when PR-7 ships — carried in `../backlog/`.
- **Deferred dimensions.** Repository storage and index size are sizes, not events, and are recorded
  as deferred under AC2 (rendered "not metered", never zero), exactly as the spec's open questions
  anticipated.
- **Prices and tiers stay out** (ADR-0008 follow-up); nothing here bills.

**New environment configuration (invariant 13):** backend `GITFROK_USAGE_GRPC_ADDR`,
`GITFROK_METERING_GAP_AFTER=15m`, `GITFROK_METERING_DIVERGENCE_TOLERANCE=0.05`,
`GITFROK_METERING_THROTTLED_CONCURRENCY=2`, `GITFROK_METERING_QUEUE_DEPTH_CAP=50`,
`GITFROK_METERING_CI_MINUTES_NOTIFY=8000`, `GITFROK_METERING_CI_MINUTES_ENVELOPE=10000`; bff
`GITFROK_USAGE_ADDR`.
