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
    - [ ] AC1: A request with no matching allow rule is **denied** (deny-by-default).
- [ ] AC2: Policies load as versioned OPA bundles from `governance/policies`.
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
    - Cache TTL/invalidation strategy to confirm during impl.
