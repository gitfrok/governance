    # SPEC-0010: CI v0 — ephemeral, isolated job execution

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** CI/CD
    - **ADRs:** 0005, 0012
    - **Task(s):** T-0017

    ## Problem / context
    Run pipelines in ephemeral, per-job gVisor sandboxes that autoscale and cannot cross tenants.

    ## In scope
    - Ephemeral per-job gVisor sandbox; teardown after each job; KEDA autoscaling on queue depth.

    ## Out of scope
    - Full pipeline DSL / caching (later).

    ## Contracts touched
    CI job/enqueue contracts in `governance/contracts` (additive); consumes `RefUpdated`.

    ## Data owned
    CI/CD owns job state; runners hold no persistent tenant data.

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: A job runs in an **ephemeral** gVisor-isolated sandbox and is destroyed after (invariant 3).
- [ ] AC2: Runners scale on queue depth via KEDA.
- [ ] AC3: A job cannot access another tenant's data or the host (isolation test passes).

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G1 isolation | per-job sandbox, no cross-tenant reach |
| G3 supply-chain | isolated build surface |
| G9 least-privilege agent | runs within customer cluster limits |

    ## Non-functional
    Cold-start within budget; sandbox overhead acceptable.

    ## Open questions / assumptions
    - Kata as an optional stronger-isolation RuntimeClass (ADR-0012) — evaluate later.
