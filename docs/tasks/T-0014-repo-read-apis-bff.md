    # T-0014: Repository read APIs + BFF aggregation

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend + bff
    - **Spec:** docs/specs/SPEC-0007-repo-read-bff-view.md
    - **ADRs:** 0022, 0015
    - **Owner:** unassigned

    ## Goal
    Expose repo/file/tree/diff read APIs from backend and aggregate them for the UI in the BFF.

    ## Acceptance criteria (test-first)
    - [ ] AC1: backend gRPC returns tree, file blob, and diff for a ref (tenant-scoped).
- [ ] AC2: the BFF aggregates these into the shaped view API — **no business logic** (invariant 18).
- [ ] AC3: unauthorized file access is denied via the PDP.

    ## Tests to write first
    - contract: backend gRPC + BFF surface against governance/contracts.
- unit (backend domain): diff/tree; bff: aggregation only (assert no domain logic).
- policy/isolation: private file access.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
