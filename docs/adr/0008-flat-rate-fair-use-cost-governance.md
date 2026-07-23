# ADR-0008: Flat-rate pricing governed by fair-use quotas (cost governance)

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G8 cost governance

## Context
Flat-rate pricing over variable costs (CI compute, storage, egress) is financially
dangerous and invites abuse (e.g. crypto-mining on CI). Note: ADR-0009 (BYO) shifts
much of this cost to the customer's cloud and greatly de-risks flat-rate.

## Decision
Charge a flat **price** per org/tier but bound the **cost** with a generous **fair-use**
envelope: past the envelope we throttle/queue rather than surprise-bill. Ship
abuse detection as a first-class subsystem, offer BYO-runner/BYO-storage, and scale
idle resources to zero.

## Consequences
**Positive:** predictable pricing customers love; bounded downside.
**Negative:** need metering + abuse detection even though we don't bill per unit.
**Follow-ups:** unit-economics model per tier.

## Alternatives considered
- **Per-seat / metered billing** — safe but contradicts the flat-rate product promise.
