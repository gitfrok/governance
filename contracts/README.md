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
  rules themselves live in `../policies/` and never travel over this wire. T-0025 (SPEC-0029,
  SPEC-0030) adds decision provenance and dry-run additively: `DecideResponse` gains `input_digest`
  and `mode` (ENFORCED|DRY_RUN) alongside the existing `policy_revision` and `decision_id`; the
  new `EvaluateDryRun` RPC evaluates a candidate bundle reference over a bounded historical range
  and returns would-be decisions labelled DRY_RUN, and `GetDecision` retrieves a decision record by
  ID. All provenance is server-produced — no request message carries a decision_id, mode,
  input_digest, bundle revision, or allowed flag, so a caller cannot assert an outcome
- `proto/git/v1/git.proto` — internal packet-stream transport between the smart-HTTP/SSH front
  doors and `git-storaged` (ADR-0004, SPEC-0015); tenant and authorization are enforced server-side.
  It also carries `MergeRef`, the single-ref compare-and-swap move Code Review uses to complete an
  authorized merge (SPEC-0019) — storage asks the PDP for it exactly as it does for a push — and
  `SetProtection`, the route by which an exact-ref branch-protection rule reaches the storage node
  that enforces direct pushes when Code Review and git-storaged do not share a process
- `proto/identity/v1/identity.proto` — credential authentication and PAT lifecycle port for
  tenant-scoped principals (SPEC-0016); it authenticates but never authorizes Git operations
- `proto/identity/v1/identity_oidc.proto` — the server-side half of the OIDC Authorization Code
  Flow with PKCE (ADR-0045, SPEC-0006): the BFF hands over the artifacts the browser flow produced,
  and gets back a tenant-scoped principal or nothing. Issuer, audience, and role vocabulary are
  per-environment configuration and cannot be named by a caller
- `proto/repository/v1/repository.proto` — tenant-scoped tree, file and diff reads for the BFF
  (SPEC-0017); authorization remains in Repository/Git. `GetMergeBase` (SPEC-0028) computes the
  merge base of two refs or commits — the comparison anchor introduction attribution needs,
  which nothing else on this surface computed — and reports a no-common-ancestor pair as
  `found = false`, never as an error
- `proto/security/v1/findings.proto` — Security/Findings ingest, read, triage, dashboard and
  merge-request surface (SPEC-0024, SPEC-0025, SPEC-0026, SPEC-0027, SPEC-0028): completed-scan
  ingestion with server-computed finding identity and lifecycle, opaque scanner provenance, and
  tenant-scoped, cursor-paginated reads; no request carries an identity, lifecycle, first-seen
  value, or authorization outcome. Triage is a separate resource keyed by finding identity —
  `SetTriage` (expected-version guarded, idempotent per request ID) and `GetTriage` (history
  included) — and the finding message gains no triage field; `GetFindingsSummary` returns counts
  and facets computed under the caller's authorization, and `ListFindings` filters extend to
  severity, scanner class, age range, lifecycle and owning team. `ListMergeRequestFindings`
  (SPEC-0028) pages the findings an opaque merge-request ID introduced — each with its triage
  state, its location at the head revision, and an attribution status of
  ATTRIBUTED/PRE_EXISTING/UNAVAILABLE with an unavailability reason; a missing scan is never an
  empty finding set, and attribution is derived state recomputed on head or merge-base move
- `proto/search/v1/search.proto` — Code Search query and index-status surface (SPEC-0034,
  SPEC-0035, ADR-0014): tenant-scoped substring/regex/symbol queries with verified context and
  signed, tenant-bound cursors; the searchable repository set is server-derived from the caller's
  permissions at query time, so no request carries a repository allow-list, permission claim, or
  authorization flag, and the response shape has no field capable of expressing an unauthorized
  total; `GetIndexStatus` reports freshness only for repositories the caller may read
- `proto/audit/v1/evidence.proto` — Audit's first RPC surface (SPEC-0031, SPEC-0032, T-0026):
  date-ranged evidence pack export. `RequestEvidencePack` accepts only a closed date range and an
  optional repository scope — no record list, section filter, or retention override — and is
  idempotent per tenant, range and request ID; `GetEvidencePackStatus` observes asynchronous
  per-section assembly with record counts; `GetEvidencePack` streams the READY pack in bounded
  chunks. A pack carries the four control sections — approvals, policy decisions, scan gates,
  access changes — with per-section chain anchors (first/last sequence and hashes), explicit gap
  markers with bounds, and embedded records (a self-contained snapshot, ADR-0055 rule 3). The
  control-section record messages are structurally incapable of carrying an attested imported
  record — no provenance block, foreign handle, declared time, or import reference — and
  `scripts/check-contracts.sh` asserts that type property against the compiled descriptor
  (SPEC-0032 AC2, inheriting T-0018 AC19 / SPEC-0011 AC14); attested history is representable
  only in the labelled `AttestedAppendix` with its provenance blocks and the admitting
  `HistoryImported` event. A policy decision record carries the deciding bundle revision and input
  digest, and `ControlDecisionMode` is a closed enum with ENFORCED only, so a DRY_RUN decision is
  not representable in a control section (SPEC-0032 AC3)
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
- `events/codereview/v1/events.proto` — Code Review opened/updated/reviewed/merged/
  protection-changed events (SPEC-0019, SPEC-0028); Repository/Git consumes only
  `BranchProtectionChanged`, and Security/Findings consumes `MergeRequestOpened` and
  `MergeRequestUpdated` (head moves and retargets) into its attribution projection
- `events/repository/v1/events.proto` — Repository context domain events (consumed by
  CI, Search, Audit — no synchronous dependency on Repository)
- `events/ci/v1/events.proto` — CI job queued/started/finished lifecycle events (SPEC-0020)
- `events/audit/v1/events.proto` — the audit trail's `AuditEvent` (ADR-0007, SPEC-0003). T-0025
  (SPEC-0029 AC8, SPEC-0030) additively adds policy decision provenance — `decision_id`,
  `bundle_revision`, `input_digest` and `policy_mode` (ENFORCED|DRY_RUN) — set when the audited
  action was gated by a PDP decision, all server-produced, with a DRY_RUN decision labelled and
  never written as an enforced control record. T-0026 (SPEC-0031, SPEC-0032) additively adds
  `EvidencePackRequested` and `EvidencePackCompleted`: opaque identifiers, tenant scope, range
  bounds and section counts — never record contents, source, or provenance bytes
- `events/security/v1/events.proto` — Security/Findings scan-ingested / finding-opened /
  finding-resolved / finding-triaged / findings-attributed events (SPEC-0024, SPEC-0025,
  SPEC-0026, SPEC-0027, SPEC-0028); opaque identifiers, tenant and repository scope, tool and
  rule identity, severity, prior / new triage state, and — for attribution — the merge-request
  identifier, the head and base revisions compared, and counts by severity — never provenance
  bytes, justification text, source, or a policy outcome
- `events/search/v1/events.proto` — Code Search repository-indexed / index-lagged events
  (SPEC-0034, SPEC-0035); opaque identifiers, tenant scope, revision and measured lag — never
  matched content or a permission fact
