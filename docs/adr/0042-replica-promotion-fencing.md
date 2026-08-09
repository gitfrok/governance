# ADR-0042: Replica promotion uses monotonic fencing terms

- **Status:** Proposed
- **Date:** 2026-08-09
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege, G5 auditability
- **Refines:** ADR-0016, ADR-0018
- **Tasks:** T-0012

## Context

ADR-0016 requires the primary plus one synchronous replica to make every acknowledged
push durable, and permits only that in-sync replica to auto-promote. ADR-0018 makes a
correlated primary-and-sync loss fail safe: writes stop until recovery or an audited
operator force-promotes an async replica. Neither ADR defines how a newly promoted
node prevents a delayed or partitioned old primary from accepting writes. Without a
monotonically checked fence, a lease timeout alone admits split-brain writes and makes
the acknowledged-push durability guarantee unprovable.

The same recovery path needs an explicit decision about who can accept an RPO loss.
ADR-0018 gives operator-only as its default but leaves it as a question; tenant
self-service would expose a durability trade-off at the wrong trust boundary for MVP.

## Decision

We will use a per-repository-shard, coordination-owned **monotonic fencing term**.

1. The coordination record contains the current primary node, the in-sync replica,
   membership version, state (`healthy`, `degraded-read-only`, or `recovering`), and
   a strictly increasing unsigned fencing term. Changing the primary is a
   compare-and-swap of that record which increments the term. A coordinator lease is
   liveness evidence only; it is not permission to write without the current term.
2. The write router obtains the current record before opening a receive-pack operation
   and attaches its term to every replica write/ack request. Each repo node durably
   remembers the highest term it has accepted per shard and rejects a lower term or a
   write from a node that is not the primary in the current record. A term change
   fences the old primary before the promoted primary accepts writes.
3. Automatic promotion is permitted only by a compare-and-swap from `healthy` to a
   new primary that was the recorded in-sync replica. A promotion commit must first
   establish the new term and fence acknowledgement, then mark the node write-ready.
   If that sequence cannot complete, the shard stays read-only; it never falls back to
   a lease-only or best-effort promotion.
4. After confirmed dual loss, the coordinator enters `degraded-read-only`. There is
   no automatic async promotion. Force-promote is **operator-only**, authorized by
   the PDP with a dedicated action, and requires an immutable audit event containing
   shard identity, previous term, selected replica, estimated RPO window, actor, and
   the new term. The same term/fence sequence applies before that replica can write.
   Tenant self-service force-promote is out of scope for MVP.
5. Replica coordination and fence commands are additive governance contracts. They
   carry opaque shard/node identifiers and terms, never repository filesystem paths,
   credentials, or a caller-provided authorization assertion.

## Consequences

**Positive:** a stale primary cannot resume writes after a promotion; auto-promotion
is mechanically limited to the replica known to hold all acknowledged pushes; every
intentional RPO trade-off is policy-gated and auditable.

**Negative / costs:** the coordinator and every storage node need durable term state,
and a failed fence makes a shard unavailable for writes rather than guessing. Promotion
contracts and kill-node integration tests are required before this path can ship.

**Follow-ups:** T-0012 defines additive coordination and audit contracts, RED tests
for stale-term rejection, in-sync-only promotion, dual-loss read-only behavior and
operator force-promote; the operator runbook states how to establish loss and estimate
the RPO window.

## Alternatives considered

- **Lease-only primary ownership** — rejected: a delayed old primary can continue
  writing after a partition, so a lease does not fence split brain.
- **Automatic promotion of the freshest async replica** — rejected by ADR-0018:
  it can silently discard acknowledged pushes.
- **Tenant self-service force-promote** — rejected for MVP: accepting an RPO loss
  requires elevated operational authorization and a recovery assessment.
