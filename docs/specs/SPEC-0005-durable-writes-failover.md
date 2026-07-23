    # SPEC-0005: Durable writes & failover

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** Repository/Git
    - **ADRs:** 0016, 0018
    - **Task(s):** T-0012

    ## Problem / context
    Pushes must be durable and survive node loss under the agreed failover policy.

    ## In scope
    - Primary + 1 sync replica write path; async fan-out; promotion rules.
- Dual-loss fail-safe (read-only) + audited operator override.

    ## Out of scope
    - Cross-region DR (later).

    ## Contracts touched
    Replica coordination messages in `governance/contracts/proto` (additive).

    ## Data owned
    Owned by Repository/Git storage tier.

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: A push is acked **only after primary + 1 sync replica** are durable (invariant 6).
- [ ] AC2: On primary loss, **only an in-sync replica** auto-promotes.
- [ ] AC3: Dual loss → **read-only**; no stale auto-promote; operator override is audited (ADR-0018).
- [ ] AC4: Fencing prevents split-brain on the promoted node.

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G1 isolation | per-tenant durability guarantees |
| G5 auditability | override emits audit event |

    ## Non-functional
    RPO=0 for the acked write path; bounded promotion time.

    ## Open questions / assumptions
    - Fencing algorithm and **force-promote tenant self-service** are parked human decisions (ADR-0018).
