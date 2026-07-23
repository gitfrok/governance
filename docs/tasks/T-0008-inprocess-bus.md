    # T-0008: In-process event bus + module `api` convention

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-0
    - **Spec:** chore — acceptance criteria below
    - **ADRs:** 0025, 0022
    - **Owner:** unassigned

    ## Goal
    Build the modular-monolith seam so modules integrate in-process the way they will over `contracts/`.

    ## Acceptance criteria (test-first)
    - [ ] AC1: `platform/bus` provides typed publish/subscribe usable by any module's `app` layer.
- [ ] AC2: A reference module exposes only its `api/` package; a second module consumes it via `api` + bus.
- [ ] AC3: Event names/shapes mirror `contracts/events/...` so extraction to Redpanda is mechanical.
- [ ] AC4: Wiring happens in `cmd/dataplane-app` (concrete impls injected), not inside modules.

    ## Tests to write first
    - unit: bus publish/subscribe + delivery semantics.
- contract: in-process event shapes match the `contracts/events` schema (shared test).
- boundary: the consumer imports only the producer's `api/`, never `internal/*`.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
