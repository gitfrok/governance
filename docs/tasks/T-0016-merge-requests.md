    # T-0016: Merge requests + protected branches + approval policy

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend + governance (policies)
    - **Spec:** docs/specs/SPEC-0009-merge-requests-approval.md
    - **ADRs:** 0004, 0006, 0007
    - **Owner:** unassigned

    ## Goal
    Enable MR/PR review with protected branches and approval rules expressed as policy-as-code.

    ## Acceptance criteria (test-first)
    - [ ] AC1: open/review/merge an MR; a protected branch blocks direct pushes.
- [ ] AC2: an approval policy (required reviewers) lives in `governance/policies` and is enforced by the PDP.
- [ ] AC3: merges/approvals emit immutable audit events (ADR-0007).

    ## Tests to write first
    - policy: Rego approval rules (allow/deny cases) in governance; integration: merge gating.
- unit (backend): MR state machine; audit: event emission.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
