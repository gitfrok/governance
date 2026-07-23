    # T-0012: Sync-replica write path + failover

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend (git-storaged)
    - **Spec:** docs/specs/SPEC-0005-durable-writes-failover.md
    - **ADRs:** 0016, 0018
    - **Owner:** unassigned

    ## Goal
    Make pushes durable and survive node loss per the failover policy.

    ## Acceptance criteria (test-first)
    - [ ] AC1: a push is acked **only after primary + 1 sync replica** are durable (invariant 6).
- [ ] AC2: on primary loss, only an in-sync replica auto-promotes.
- [ ] AC3: dual loss → **read-only** (no stale auto-promote); operator override is audited (ADR-0018).

    ## Tests to write first
    - integration: kill-node scenarios; unit: ack/quorum logic; contract: coordination messages.
- audit: override path emits an immutable audit event.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
