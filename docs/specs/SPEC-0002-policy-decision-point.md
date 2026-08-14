# SPEC-0002: Policy Decision Point (deny-by-default)

- **Status:** Approved
- **Owner:** platform
- **Context(s):** Policy (PDP)
- **ADRs:** 0006, 0022
- **Task(s):** T-0005

## Problem / context
All authorization flows through a central PDP evaluating policy-as-code; no inline checks.

## In scope
- OPA-based PDP consulted by BFF/services for protected actions.
- Versioned policy bundles loaded from `governance/policies`.
- Decision caching with correct invalidation.

## Out of scope
- Policy authoring UI (control plane, later).

## Contracts touched
A `Decision` request/response (subject, action, resource, context) in `governance/contracts` (additive).

## Data owned
Policy bundles are owned by governance; the PDP holds no domain data.

## Acceptance criteria (each becomes a test)
- [x] AC1: A request with no matching allow rule is **denied** (deny-by-default). *`policies/gitsaas/authz`
      defaults to deny; the gate asserts it evaluates to `false` — not undefined — for an empty
      input; and the backend adapter returns the zero `Decision` on every failure path, so a caller
      that ignores the error still denies.*
- [x] AC2: Policies load as versioned OPA bundles from `governance/policies`. *`policies/` is the
      bundle root; `opa build -b` validates the manifest revision and that its roots cover every
      package, gated by `scripts/check-policies.sh`.*
- [x] AC3: A sample protected action is allowed/denied purely by policy; decisions are cached.
      *`repo.read`, guarded in `bff/internal/aggregate` before the read rather than after. The PEP
      caches by request and invalidates by bundle revision.*
- [x] AC4: No service performs an inline permission check that bypasses the PDP. *An
      `inline-permission-check` fitness function in backend and bff. A **tripwire, not a proof** —
      authorization logic has no import signature the way every other boundary rule does. The limit
      is documented in both implementations and in T-0005.*

## Governance mapping (G1–G9)
| Objective | How |
|---|---|
| G2 least privilege | deny-by-default; central evaluation |
| G4 change governance | rules are reviewed policy-as-code |
| G5 auditability | decisions are logged (with SPEC-0003) |

## Non-functional
Decision p99 < a few ms cached; policy reload without downtime.

## Open questions / assumptions
- Cache TTL/invalidation strategy to confirm during impl. **Resolved in part (T-0005):**
  invalidation is by bundle revision, not by time. `DecideResponse.policy_revision` carries the
  `.manifest` revision that produced the decision, so a cache keyed on it is emptied by a policy
  change without anyone having to remember to flush it. A TTL still bounds staleness of the
  *inputs* (a subject's roles), and its value is set where the PEP lives.
- The PDP is **embedded**, not a sidecar. ADR-0025 admits only `git-storaged`, CI runners, the
  agent and the operator as separate processes, so the PDP is a module in the plane binary and the
  bundle reaches it as configuration (invariant 13) rather than being compiled in — a bundle baked
  into a consumer's binary would fork the policy away from governance (invariant 21).
- **Recorded deployment-posture limit (Phase-2 code review H2, 2026-08-14).** `Decide` is served on
  the dataplane gRPC door (`backend/cmd/dataplane-app/gitfront.go`), which is unauthenticated — no
  transport credentials, no authentication interceptor, no tenant-pinning interceptor — so the subject
  a decision is made about is the caller's assertion. For `Decide` this is inherent to a PDP call and
  was the Phase-1 posture (the BFF is the only intended client); Phase 2 widened the same door to the
  findings, evidence, grant and search services, which likewise take tenant/actor/roles from the
  request body. What mitigates it today is network isolation of the port plus the single-tenant dev
  posture. Follow-up: door authentication and a server-derived tenant-pinning interceptor before any
  deployment posture that does not isolate the port. Recorded alongside the phase exit verdict
  (`../plans/phase-2-ultimate-wedge.md`, note (d)); this records a limit, not a decision — no ADR.
