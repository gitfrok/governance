    # T-0011: Smart-HTTP + SSH front doors

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend
    - **Spec:** docs/specs/SPEC-0004-git-storage-transport.md
    - **ADRs:** 0004, 0003
    - **Owner:** unassigned

    ## Goal
    Expose git over smart-HTTP and SSH, authenticating and routing to the Git-RPC service.

    ## Acceptance criteria (test-first)
    - [ ] AC1: `git clone/push` works over HTTPS with a PAT and over SSH with a key.
- [ ] AC2: auth resolves the tenant + identity before any storage call (deny on failure).
- [ ] AC3: unauthorized/anonymous access to a private repo is denied.

    ## Tests to write first
    - integration: real git client over both transports; unit: auth/route logic.
- policy/isolation: private-repo access control.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
