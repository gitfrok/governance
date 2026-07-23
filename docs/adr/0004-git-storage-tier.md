# ADR-0004: Git storage via a Git-RPC service over sharded, replicated nodes

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G1 isolation, reliability

## Context
Repos are the core, stateful asset. App servers touching the filesystem directly
prevents horizontal scaling and safe sharding.

## Decision
Front all repo access with a **Git-RPC service** (Gitaly-style); app servers never
touch disk. Repos are **sharded** across storage nodes via a router, and
**replicated** for HA (Praefect-style). Large objects — Git LFS, CI artifacts, and
registry blobs — live in **object storage**, not on repo nodes.

## Consequences
**Positive:** horizontal scale; clean HA story; app tier is stateless.
**Negative:** replication/failover for stateful repos is the hardest reliability problem —
must be built early.
**Follow-ups:** define failover and consistency behavior explicitly (own ADR later).

## Alternatives considered
- **App servers on shared NFS** — simple but a scaling/reliability dead end.
