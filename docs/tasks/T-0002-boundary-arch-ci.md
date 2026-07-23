    # T-0002: Boundary/arch enforcement in CI

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-0
    - **Spec:** chore — acceptance criteria below
    - **ADRs:** 0022, 0025
    - **Owner:** unassigned

    ## Goal
    Machine-enforce invariants 14–18 so coupling cannot regress.

    ## Acceptance criteria (test-first)
    - [ ] AC1: A `module/internal/domain` package importing infra (pg/redpanda/http/opa/zitadel) fails the build.
- [ ] AC2: A module importing another module's `internal/*` fails the build (cross-module only via `api/` or the bus).
- [ ] AC3: The BFF importing any module's `internal/*` fails the build (aggregation only).
- [ ] AC4: A module's `api/` package exposing an infra type (pg/http/redpanda/…) fails the build.
- [ ] AC5: CI runs these on every PR and blocks merge on violation.

    ## Tests to write first
    - boundary/arch tests (go-arch-lint or import-linter equivalent) with fixtures that
  intentionally violate each rule and must be caught.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
