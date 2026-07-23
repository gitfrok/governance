    # T-0006: Append-only audit log

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-2
    - **Spec:** docs/specs/SPEC-0003-audit-log.md
    - **ADRs:** 0007, 0022
    - **Owner:** unassigned

    ## Goal
    Tamper-evident, append-only audit sink with no delete path.

    ## Acceptance criteria (test-first)
    - [ ] AC1: Writes are append-only; there is no update/delete API.
- [ ] AC2: Entries are hash-chained; a verifier detects tampering.
- [ ] AC3: A sample sensitive action emits an audit event.

    ## Tests to write first
    - unit: hash-chain writer + verifier (including a tamper case that must fail).
- integration: persistence with no mutation path exposed.
NOTE: write SPEC first.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
