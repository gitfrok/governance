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
  doors and `git-storaged` (ADR-0004, SPEC-0015); tenant and authorization are enforced server-side.
  It also carries `MergeRef`, the single-ref compare-and-swap move Code Review uses to complete an
  authorized merge (SPEC-0019) — storage asks the PDP for it exactly as it does for a push
- `proto/identity/v1/identity.proto` — credential authentication and PAT lifecycle port for
  tenant-scoped principals (SPEC-0016); it authenticates but never authorizes Git operations
- `proto/repository/v1/repository.proto` — tenant-scoped tree, file and diff reads for the BFF
  (SPEC-0017); authorization remains in Repository/Git
- `proto/replica/v1/replica.proto` — sync-replica coordination for the Git write path (SPEC-0018,
  ADR-0016/0018/0042): shard records, fencing terms, durable-primary and sync acknowledgements,
  compare-and-swap auto-promotion, and the audited platform-operator force-promote
- `proto/ci/v1/ci.proto` — immutable CI job enqueue/read/cancel commands (SPEC-0020); runners,
  source capabilities, queue rows, and Kubernetes details remain private to CI/CD
- `proto/codereview/v1/codereview.proto` — merge-request, review, and exact-ref branch-protection
  commands (SPEC-0019); every authorization-sensitive command receives a PDP decision with
  server-derived context, and no request carries an approval count, protection result, or allow flag
- `proto/bff/v1/browser.proto` — proto-JSON shapes for the BFF tree/file/diff browser views
  (SPEC-0021); tenant and actor are deliberately absent, and the BFF maps only from
  RepositoryReader results
- `events/codereview/v1/events.proto` — Code Review opened/reviewed/merged/protection-changed
  events (SPEC-0019); Repository/Git consumes only `BranchProtectionChanged`
- `events/repository/v1/events.proto` — Repository context domain events (consumed by
  CI, Search, Audit — no synchronous dependency on Repository)
- `events/ci/v1/events.proto` — CI job queued/started/finished lifecycle events (SPEC-0020)
- `events/audit/v1/events.proto` — the audit trail's `AuditEvent` (ADR-0007, SPEC-0003)
