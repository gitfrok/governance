# ADR-0061: The control plane is the authority for fair-use metering

- **Status:** Accepted (2026-08-14)
- **Deciders:** platform
- **Supersedes / superseded by:** —
- **Related:** ADR-0008 (flat-rate + fair use), ADR-0011, ADR-0017, PRD §6, SPEC-0041, T-0034

## Context

PR-23 requires usage metered per fair-use dimension and visible to the customer before an envelope
is reached. ADR-0008 fixes flat-rate plus fair use and leaves prices open; the PRD fixes the
dimensions — seats, repository count, repository storage, CI job minutes, CI concurrency, scan
volume, code-search index size, egress — and the enforcement behaviour, which is throttle-and-notify
and never blocking git.

Under BYO the counted work happens in the customer's own cluster (ADR-0009). Whoever holds the
counters holds the number the commercial conversation runs on.

## Decision

**The control plane counts, from the telemetry it already receives over the agent channel.** A data
plane's report is an input to health and operations, never the billing number.

1. **Authoritative counters live in the control plane**, derived from events the agent streams under
   ADR-0017's protocol. A dimension that cannot be derived from received telemetry is not a metered
   dimension until it can be — the PRD's list is the target, and SPEC-0041 states which dimensions
   are derivable at Phase 3 and which are deferred, rather than implying full coverage.
2. **A data plane cannot under-report itself into a smaller envelope**, because it is not asked. Its
   own counters may be shown as an operational signal and may diverge; divergence is a health
   finding, not a billing adjustment.
3. **Missing telemetry is visible, never zero.** A disconnected or silent data plane produces a gap
   in the usage view marked as a gap. Absence of events must never render as absence of usage — the
   same rule the evidence pack applies to truncation (SPEC-0031 AC10).
4. **Enforcement stays where the PRD put it:** throttle and notify. Envelope state is computed in
   the control plane and carried to the data plane as desired state; git push, fetch, clone and all
   reads remain fully available at every envelope condition, and read-only remains reserved for the
   PR-7 durability mode (ADR-0018).
5. **No automatic metered overage billing.** ADR-0008's flat-rate promise stands; sustained overage
   is a plan conversation. Changing that needs a superseding ADR, not a metering feature.

**Rejected: the data plane meters and reports totals.** Exact and cheap — it sees everything,
including work that never becomes an event — but it makes the customer's own cluster the source of
truth for the number they are measured against, and a misconfigured install under-reports silently.

**Rejected: both, with reconciliation.** The only option that detects tampering, and the only one
needing a policy for what to do when the two disagree. Two metering paths and a divergence policy is
more machinery than a flat-rate plan with no metered billing can justify today. If a dimension is
ever billed rather than envelope-checked, revisit this first.

## Consequences

- Telemetry becomes load-bearing: an event stream that was operational signal now feeds a commercial
  surface, so its schema is a contract and its gaps are visible product state (decision 3).
- Some PRD dimensions are harder to derive centrally than to count locally — repository storage and
  index size are sizes, not events. SPEC-0041 must say which dimensions Phase 3 actually meters and
  which are recorded as deferred, and the usage view must not imply coverage it does not have.
- ADR-0008's unit-economics follow-up stays open and is now better fed: dimensions and derivation are
  fixed here, prices are not.
- A customer's usage view and our own read the same counters. There is no second, internal number.
