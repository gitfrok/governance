# contracts/ — the ONLY shared surface between contexts (ADR-0022)

Cross-context communication happens **only** through the contracts here. No context imports
another context's internal Go packages — that would be coupling. Instead:

- `proto/<context>/v1/*.proto`  — **synchronous** gRPC service contracts
- `events/<context>/v1/*.proto` — **asynchronous** domain event schemas (published to Redpanda)

Prefer **events** for cross-context reactions (choreography); use gRPC only when the caller
needs a direct response.

## Versioning (both proto and events)
- **Package = version** (`v1`, `v2`…). Breaking change → a **new package**, served alongside.
- **Additive only** within a version: never change or reuse a field number or type.
- **Reserve** removed tags/names; enums keep `*_UNSPECIFIED = 0`.
- Generated code lives under `gen/` (built in CI) — never hand-edit.

## Current contracts
- `proto/agent/v1/agent.proto` — agent ↔ control-plane (ADR-0011, ADR-0017)
- `events/repository/v1/events.proto` — Repository context domain events (consumed by
  CI, Search, Audit — no synchronous dependency on Repository)
