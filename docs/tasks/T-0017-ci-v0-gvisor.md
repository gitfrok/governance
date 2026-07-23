    # T-0017: CI v0: gVisor sandbox runner + KEDA

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend (ci + runner)
    - **Spec:** docs/specs/SPEC-0010-ci-ephemeral-isolation.md
    - **ADRs:** 0005, 0012
    - **Owner:** unassigned

    ## Goal
    Run pipelines in ephemeral, per-job gVisor sandboxes that autoscale.

    ## Acceptance criteria (test-first)
    - [ ] AC1: a job runs in an **ephemeral** gVisor-isolated sandbox and is destroyed after (invariant 3).
- [ ] AC2: runners scale on queue depth via KEDA.
- [ ] AC3: a job cannot access another tenant's data or the host (isolation test).

    ## Tests to write first
    - integration: job lifecycle + teardown; isolation: cross-tenant/host escape attempts denied.
- unit: scheduling/queue logic.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
