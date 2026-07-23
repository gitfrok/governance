# ADR-0016: Git storage failover — primary + one synchronous replica + async fan-out

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** reliability/durability, G1 isolation
- **Refines:** ADR-0004

## Context
ADR-0004 chose sharded, replicated repo nodes but left the consistency/failover model
open. Repos are the crown-jewel stateful asset. Losing an acknowledged push is
unacceptable, but replicating synchronously to *all* replicas adds too much write latency.

## Decision
Per repo: acknowledge a push only after it is durable on the **primary AND one
synchronous replica** (so an acked write survives any single-node loss), then fan out to
**additional asynchronous replicas** for read scaling and broader durability. A
coordination layer (Praefect-style) tracks the in-sync replica and orchestrates failover:
on primary loss, **only the in-sync replica may be promoted** (it holds all acked writes);
stale async replicas re-sync. Writes go to the primary; reads may be served from any
up-to-date replica. Place the synchronous replica in a **different AZ, same region** to
balance durability and latency.

## Consequences
**Positive:** RPO ≈ 0 for any single-node failure; lower write latency than all-sync; read
scaling from async replicas.
**Negative:** write latency gated on the slower of {primary, sync replica}; promotion must
**fence** stale replicas to avoid split-brain / data loss.
**Follow-ups:** define RPO/RTO targets; fencing + quorum for promotion; **decide behavior
when primary AND sync replica are lost together** (halt writes vs accept RPO>0 by promoting
an async replica); AZ placement policy.

## Alternatives considered
- **All-synchronous replication** — safest but too slow on writes.
- **All-asynchronous** — fastest but can lose the last acked write on failover (rejected).
