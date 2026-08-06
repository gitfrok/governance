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
- [ ] AC1: A request with no matching allow rule is **denied** (deny-by-default). *Policy half done
      (T-0005, governance): `policies/gitsaas/authz` defaults to deny and the gate asserts it
      evaluates to `false` — not undefined — for an empty input. The PDP service half is open.*
- [x] AC2: Policies load as versioned OPA bundles from `governance/policies`. *`policies/` is the
      bundle root; `opa build -b` validates the manifest revision and that its roots cover every
      package, gated by `scripts/check-policies.sh`.*
- [ ] AC3: A sample protected action is allowed/denied purely by policy; decisions are cached.
- [ ] AC4: No service performs an inline permission check that bypasses the PDP.

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
