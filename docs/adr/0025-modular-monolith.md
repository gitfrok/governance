# ADR-0025: Modular monolith for the application layer

- **Status:** Accepted
- **Date:** 2026-07-21
- **Refines:** ADR-0022 (HCLC)
- **Relates to:** ADR-0009 (CP/DP split), ADR-0004 (git tier), ADR-0005/0012 (CI), ADR-0011 (agent), ADR-0013 (operator)

## Context
ADR-0022 gives us bounded contexts with hexagonal boundaries but leaves deployment open.
Microservices now would be premature: they multiply operational surface and — critically —
add pods to the **customer's** cluster under BYO (ADR-0009), which is a real cost. We want the
modularity benefit without the distributed-systems tax, while staying easy to split later.

## Decision
The **application layer ships as one modular-monolith binary per plane**:
`cmd/dataplane-app` and `cmd/controlplane-app`.

- Each bounded context is a **module** at `/modules/<ctx>/` with:
  - `api/` — the public in-process surface (types + interfaces); the **only** import entry point.
  - `internal/{domain,app,adapters}/` — everything else, made **Go-unimportable** across modules
    by the `internal/` rule. Dependencies point inward (adapters → app → domain).
- **Cross-module interaction in-process** goes through the target module's `api` package or the
  **in-process event bus** (`platform/bus`). Never import another module's `internal/*`.
- Same governance as cross-process: prefer events; **schema-per-context**; no cross-module DB access.
- **Separate processes by necessity** (not part of the monolith): `git-storaged` (ADR-0004),
  CI runners (ADR-0005/0012, untrusted execution), the **agent** (ADR-0011, runs in the customer
  cluster), the **operator** (ADR-0013). Control- and data-plane are separate binaries per ADR-0009.
- **Extraction-ready:** the in-process `api` + bus mirror the semantics of `contracts/`, so a
  module can be promoted to its own service (ADR-0026) by swapping in-process calls for
  gRPC/events **without changing callers**.

## Consequences
**Positive:** smallest ops + BYO footprint; a single transaction boundary per plane (local
transactions early); enforced modularity keeps future extraction cheap; fast local dev.
**Negative / mitigations:** boundaries can erode → enforced by Go `internal/` + architecture
fitness functions (tasks T-0002/T-0009); one binary's build/test time grows with scope → that
is itself an ADR-0026 extraction trigger.

## Alternatives considered
- **Microservices now** — rejected: premature; BYO pod sprawl; distributed-txn pain.
- **Unstructured monolith** — rejected: no clean extraction path.
- **One binary for everything (incl. CI/agent)** — rejected: impossible/unsafe (isolation, CP/DP split).
