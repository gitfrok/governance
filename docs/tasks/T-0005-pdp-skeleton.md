    # T-0005: PDP skeleton (OPA)

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-2
    - **Spec:** docs/specs/SPEC-0002-policy-decision-point.md
    - **ADRs:** 0006, 0022
    - **Owner:** unassigned

    ## Goal
    Deny-by-default policy decision point consulted by the BFF/services.

    ## Acceptance criteria (test-first)
    - [ ] AC1: A request with no matching allow policy is denied.
- [ ] AC2: Policies live in a versioned policy dir and load as OPA bundles.
- [ ] AC3: The BFF calls the PDP for a sample protected action; decision is cached.

    ## Tests to write first
    - policy: unit tests over Rego (allow/deny cases).
- contract/integration: BFF↔PDP decision path.
NOTE: write SPEC first (behavioral) before RED — see SDD.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
