# ADR-0018: Behavior when the primary AND synchronous replica are lost together

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** durability (RPO), availability, G5 auditability
- **Refines:** ADR-0016

## Context
ADR-0016 guarantees RPO ≈ 0 for any *single*-node loss (primary + one synchronous
replica). It left open the correlated **dual loss** of the primary **and** its in-sync
replica (e.g. an AZ-pair failure). The remaining async replicas may be missing the last
acknowledged pushes, so promoting one risks silently losing acked writes.

## Decision
**Fail safe.** On confirmed loss of both the primary and its synchronous replica, the
affected repo shards go **read-only (writes halted), preserving RPO**, rather than
auto-promoting a possibly-stale async replica. Recovery, in order of preference:
1. **Recover/reattach** either in-sync node if at all possible → zero data loss.
2. **Operator-initiated, audited force-promote** of the most up-to-date async replica,
   which **explicitly accepts a bounded RPO > 0**. This action requires elevated authz,
   is written to the immutable audit log (ADR-0007) with the estimated data-loss window,
   and fences the lost nodes to prevent split-brain.

We **never auto-promote** an async replica. Affected repos surface a clear
`read-only (degraded)` status with the reason. Scope is limited to affected shards, not global.

## Consequences
**Positive:** acknowledged pushes are never silently lost; the availability escape hatch
still exists but is conscious and accountable; consistent with governance-first values.
**Negative:** affected repos lose write availability during correlated dual-loss until
recovery or an operator acts; needs strong alerting, an operator runbook, and a way to
estimate the RPO window before force-promote.
**Follow-ups:** "most up-to-date async replica" selection + fencing algorithm; force-promote
runbook + authorization; SLA wording for multi-AZ correlated loss.

## The one knob left for you
- **Is force-promote ever tenant self-service?** Default here is **operator-only**. Flip to
  tenant self-service only if you want customers to trade durability for availability
  themselves (still audited). Revisit as a superseding ADR if you change this.

## Alternatives considered
- **Auto-promote async (favor availability)** — rejected as default: silently loses acked pushes.
- **Global write halt** — unnecessary; scope to affected shards only.
