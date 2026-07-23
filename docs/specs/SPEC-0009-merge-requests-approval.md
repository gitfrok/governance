    # SPEC-0009: Merge requests, protected branches & approval policy

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** Code Review + Policy
    - **ADRs:** 0004, 0006, 0007
    - **Task(s):** T-0016

    ## Problem / context
    Enable MR/PR review with protected branches and approval rules as policy-as-code.

    ## In scope
    - MR lifecycle (open/review/merge); protected-branch enforcement; required-reviewer policy in `governance/policies`; audit on merge/approve.

    ## Out of scope
    - Advanced merge trains/queues (later).

    ## Contracts touched
    MR RPCs/events in `governance/contracts`; approval rules in `governance/policies`.

    ## Data owned
    Code Review owns MR state; Policy owns the approval rules; Audit records outcomes.

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: Open/review/merge an MR; a protected branch blocks direct pushes.
- [ ] AC2: An approval policy (required reviewers) in `governance/policies` is enforced by the PDP.
- [ ] AC3: Merges/approvals emit immutable audit events (ADR-0007).

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G4 change governance | approvals as policy-as-code |
| G2 least privilege | PDP-enforced gating |
| G5 auditability | merge/approve audited |

    ## Non-functional
    Merge-gate decision within interactive latency.

    ## Open questions / assumptions
    - Default protected-branch ruleset for new repos to confirm.
