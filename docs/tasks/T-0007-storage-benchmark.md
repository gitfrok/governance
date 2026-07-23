    # T-0007: Storage benchmark: SeaweedFS-FUSE vs block volumes

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-3
    - **Spec:** chore — acceptance criteria below
    - **ADRs:** 0020, 0023, 0016
    - **Owner:** unassigned

    ## Goal
    Settle the ADR-0020 open knob: is FUSE viable for live bare repos, or block volumes only?

    ## Acceptance criteria (test-first)
    - [ ] AC1: Benchmark clone / push / gc / status latency + throughput on (a) SeaweedFS-FUSE
      and (b) fast block volumes, under concurrent load.
- [ ] AC2: Include correctness checks (concurrent pushes, fsync/rename semantics).
- [ ] AC3: Produce a result doc and a **Proposed ADR** either confirming block-volumes
      default or amending ADR-0016.

    ## Tests to write first
    - integration/bench harness; not unit-tested code but results must be reproducible (scripted).

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
