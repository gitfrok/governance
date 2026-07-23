    # T-0009: Architecture fitness functions (extraction-readiness)

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-0
    - **Spec:** chore — acceptance criteria below
    - **ADRs:** 0026, 0025, 0022
    - **Owner:** unassigned

    ## Goal
    Continuously prove the monolith stays service-extractable, and track ADR-0026 triggers.

    ## Acceptance criteria (test-first)
    - [ ] AC1: Each module builds and its tests run in isolation (no sibling `internal/` deps).
- [ ] AC2: The module dependency graph is acyclic; a cycle fails the build.
- [ ] AC3: No module `api/` surface references an infra type (extends T-0002 AC4 fleet-wide).
- [ ] AC4: A report emits the ADR-0026 trigger signals (per-module build/test time; fan-in/out)
      so extraction decisions are data-driven.

    ## Tests to write first
    - boundary/arch: isolation build, acyclicity check, api-purity check.
- a reporting test/script that fails if a tracked trigger crosses its agreed budget.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
