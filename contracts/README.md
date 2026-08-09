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
- `proto/policy/v1/policy.proto` — the Policy Decision Point (ADR-0006, SPEC-0002). Synchronous
  against the usual preference for events, because a PEP cannot proceed without the answer; the
  rules themselves live in `../policies/` and never travel over this wire
- `proto/git/v1/git.proto` — internal packet-stream transport between the smart-HTTP/SSH front
  doors and `git-storaged` (ADR-0004, SPEC-0015); tenant and authorization are enforced server-side
- `proto/identity/v1/identity.proto` — credential authentication and PAT lifecycle port for
  tenant-scoped principals (SPEC-0016); it authenticates but never authorizes Git operations
- `proto/repository/v1/repository.proto` — tenant-scoped tree, file and diff reads for the BFF
  (SPEC-0017); authorization remains in Repository/Git
- `proto/ci/v1/ci.proto` — immutable CI job enqueue/read/cancel commands (SPEC-0020); runners,
  source capabilities, queue rows, and Kubernetes details remain private to CI/CD
- `events/repository/v1/events.proto` — Repository context domain events (consumed by
  CI, Search, Audit — no synchronous dependency on Repository)
- `events/ci/v1/events.proto` — CI job queued/started/finished lifecycle events (SPEC-0020)
- `events/audit/v1/events.proto` — the audit trail's `AuditEvent` (ADR-0007, SPEC-0003)
