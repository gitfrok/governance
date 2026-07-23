    # SPEC-0003: Append-only, tamper-evident audit log

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** Audit
    - **ADRs:** 0007, 0022
    - **Task(s):** T-0006

    ## Problem / context
    Sensitive actions must be recorded immutably for compliance and investigation.

    ## In scope
    - Append-only writer; hash-chained entries; a verifier.
- Emission from a sample sensitive action.

    ## Out of scope
    - Audit UI + evidence export (Phase 2).

    ## Contracts touched
    An `AuditEvent` shape in `governance/contracts/events` (additive).

    ## Data owned
    Audit owns its store; **no update/delete path** exists (invariant 5).

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: Writes are append-only; there is no update/delete API surface.
- [ ] AC2: Entries are hash-chained; a verifier detects any tampering (a mutated entry fails).
- [ ] AC3: A sample sensitive action emits an audit event.
- [ ] AC4: Audit is a separate store from observability/telemetry.

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G5 auditability | immutable hash-chained trail |
| G6 compliance | basis for evidence export |

    ## Non-functional
    Write path adds negligible latency; verification is offline/batchable.

    ## Open questions / assumptions
    - Retention/rotation policy is a later decision.
