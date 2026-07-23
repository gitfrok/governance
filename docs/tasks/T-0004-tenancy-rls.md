    # T-0004: Tenancy + RLS baseline

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-2
    - **Spec:** docs/specs/SPEC-0001-tenancy-isolation.md
    - **ADRs:** 0003, 0022, 0007
    - **Owner:** unassigned

    ## Goal
    Implement SPEC-0001: tenant_id everywhere + RLS + deny-by-default scoping.

    ## Acceptance criteria (test-first)
    - [ ] AC1–AC4: exactly the acceptance criteria in SPEC-0001.

    ## Tests to write first
    - policy/isolation (mandatory): cross-tenant read/write returns nothing / is rejected.
- unit: tenant-scoping helper sets/*requires* context.
- integration: RLS policies on real Postgres 18.
- boundary: migration lint fails on a tenant table lacking tenant_id + RLS.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
