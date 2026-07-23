    # T-0010: Git-RPC storage service

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend (git-storaged)
    - **Spec:** docs/specs/SPEC-0004-git-storage-transport.md
    - **ADRs:** 0004, 0016
    - **Owner:** unassigned

    ## Goal
    Serve git object/ref operations over an internal RPC on sharded, replicated storage.

    ## Acceptance criteria (test-first)
    - [ ] AC1: clone/fetch/push of a small repo succeed via the RPC against one storage node.
- [ ] AC2: repos live on **block volumes**, not FUSE (invariant 7); LFS/artifacts use SeaweedFS-S3.
- [ ] AC3: every op is tenant-scoped; a wrong-tenant repo handle is denied (invariants 1–2).

    ## Tests to write first
    - unit (domain): ref/pack operations; contract: the RPC surface; integration: real repo on a block volume.
- policy/isolation: cross-tenant repo access denied.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
