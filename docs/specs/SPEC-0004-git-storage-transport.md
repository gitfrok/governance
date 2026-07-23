    # SPEC-0004: Git storage & transport (RPC + smart-HTTP + SSH)

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** Repository/Git
    - **ADRs:** 0004, 0003, 0016
    - **Task(s):** T-0010, T-0011

    ## Problem / context
    Serve git operations on sharded, replicated storage, fronted by smart-HTTP and SSH.

    ## In scope
    - Internal Git-RPC for object/ref ops on block-volume-backed repos.
- Smart-HTTP (PAT) and SSH (key) front doors that authenticate, resolve tenant, and route.
- LFS/artifacts to SeaweedFS-S3.

    ## Out of scope
    - Sync-replica write path + failover (SPEC-0005); code review (SPEC-0009).

    ## Contracts touched
    The Git-RPC service surface in `governance/contracts/proto` (additive).

    ## Data owned
    Repository/Git owns repo metadata + on-disk bare repos; other contexts react via `RefUpdated` events.

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: `git clone/fetch/push` of a small repo succeed over HTTPS (PAT) and SSH (key).
- [ ] AC2: Repos live on **block volumes**, not FUSE (invariant 7); LFS/artifacts use SeaweedFS-S3.
- [ ] AC3: Every op is tenant-scoped; a wrong-tenant handle and anonymous access to a private repo are **denied**.
- [ ] AC4: A successful push emits `RefUpdated` (consumed independently by CI/search/audit).

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G1 isolation | tenant-scoped handles |
| G2 least privilege | authN/Z before storage access |
| G5 auditability | ref updates are events |

    ## Non-functional
    Clone/push latency within budget under concurrency; correct fsync/rename semantics.

    ## Open questions / assumptions
    - Sharding/placement details firmed up alongside SPEC-0005 and the T-0007 benchmark.
