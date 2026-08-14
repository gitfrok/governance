# SPEC-0041: Fair-use metering and envelope behaviour

- **Status:** Draft
- **Owner:** platform
- **Context(s):** Control plane (counts, decides envelope state) · data plane (applies desired state)
- **ADRs:** 0061 (decides authority), 0008 (flat-rate + fair use), 0011, 0017, 0018
- **Task(s):** T-0034

## Problem / context

PR-23: usage is metered per fair-use dimension and visible to the customer *before* an envelope is
reached. ADR-0008 fixes flat-rate plus fair use; PRD §6 fixes the dimensions and the enforcement
behaviour — throttle and notify, never block git. ADR-0061 fixes the authority: the control plane
counts, from telemetry it already receives, and a data plane's own numbers are an operational signal
rather than the billing number.

The risk this spec exists to prevent is a usage view that looks complete and is not. A dimension we
cannot derive centrally must be absent and labelled, not shown as zero.

## In scope

- Which PRD §6 dimensions Phase 3 meters, and which are recorded as deferred with the reason.
- Derivation of counters from received telemetry, and how gaps render.
- Envelope thresholds, notification, and the throttle behaviours the PRD specifies.
- The customer-visible usage view.

## Out of scope

- Prices, tiers and plan names — ADR-0008's unit-economics follow-up.
- Metered overage billing, which ADR-0008 forbids without a superseding ADR.
- Any enforcement that degrades git availability or correctness.

## Contracts touched

`contracts/proto/agent/v1` — additive telemetry and envelope-state messages within the existing
envelopes.

## Data owned

The control plane owns counters, envelope state and the usage view. The data plane owns its own
operational counters, which it may report and which are never authoritative (ADR-0061 §2).

## Acceptance criteria (each becomes a test)

- [ ] AC1: Counters are derived in the control plane from received telemetry. A data plane's reported
  totals never change a counter; where both exist and diverge, the divergence is a health finding
  with both numbers shown, not an adjustment.
- [ ] AC2: Dimension coverage is explicit. Every PRD §6 dimension is either metered or listed as
  deferred with its reason, in this spec and in the usage view. A deferred dimension renders as "not
  metered", never as zero or as within-envelope.
- [ ] AC3: Missing telemetry renders as a gap over the affected interval, never as zero usage
  (ADR-0061 §3). A disconnected data plane makes the gap visible in the customer's own view.
- [ ] AC4: Crossing a notification threshold produces an in-product notice and an email to the
  platform engineer, naming the dimension and its trend — before the envelope is reached, not on
  breach.
- [ ] AC5: Envelope exceeded on a CI dimension reduces job concurrency and caps queue depth. Running
  jobs finish; queued jobs are delayed and never silently dropped, and the delay is visible as a
  cause on the job.
- [ ] AC6: Envelope exceeded on a storage or index dimension warns and reports, and may throttle new
  large-object writes. Nothing already stored becomes unreadable.
- [ ] AC7: **Git stays available in every envelope state.** Push, fetch, clone and all reads succeed
  under any breach of any dimension. A test asserts this per dimension, because this is the promise
  most easily broken by a well-meaning throttle.
- [ ] AC8: A repository is never made read-only for a commercial reason. Read-only remains reserved
  for the PR-7 durability mode (ADR-0018), and the two states are distinguishable in the product.
- [ ] AC9: Envelope state reaches the data plane as desired state over the agent channel and is
  applied there; the control plane never reaches into the cluster to enforce it.
- [ ] AC10: The customer and we read the same counters. There is no second internal number, and the
  view a customer sees is the one an envelope decision was made from.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | counters and views are tenant-scoped |
| G6 evidence | envelope decisions cite the counters and interval they were made from (AC10) |
| G8 footprint | fair use is enforced by throttling, never by degrading correctness (AC7, AC8) |
| G9 operability | gaps and deferred dimensions are visible product state, not silent zeros (AC2, AC3) |

## Non-functional

- Thresholds and envelope values are per-tenant configuration, not compiled in.
- Counter derivation must survive control-plane restart without double-counting or losing an
  interval; the interval boundary is recorded, not inferred from wall-clock at read time.

## Open questions / assumptions

- Repository storage and code-search index size are sizes rather than events, and are the likeliest
  deferrals under AC2. Whether the data plane may report them as an operational signal while they
  stay unmetered is a product call this spec leaves open.
- Assumed: seats are derivable from identity events the control plane already holds. If they are not,
  seats join the deferred list rather than being estimated.
