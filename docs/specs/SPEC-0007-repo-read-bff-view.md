    # SPEC-0007: Repository read APIs & BFF view aggregation

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** Repository/Git + BFF
    - **ADRs:** 0022, 0015
    - **Task(s):** T-0014

    ## Problem / context
    Expose repo/tree/file/diff reads from backend and aggregate them for the UI in the BFF.

    ## In scope
    - Backend gRPC: tree, file blob, diff for a ref (tenant-scoped, PDP-checked).
- BFF aggregation into a shaped view API (no business logic).

    ## Out of scope
    - Write/MR flows (SPEC-0009).

    ## Contracts touched
    Read RPCs + BFF view API in `governance/contracts` (additive).

    ## Data owned
    Backend owns repo data; BFF owns no data (aggregation only).

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: Backend returns tree, file blob, and diff for a ref (tenant-scoped).
- [ ] AC2: The BFF aggregates these into the view API with **no business logic** (invariant 18).
- [ ] AC3: Unauthorized file access is **denied** via the PDP.

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G1 isolation | tenant-scoped reads |
| G2 least privilege | PDP authZ on file access |

    ## Non-functional
    View API p95 within budget for typical repos; diffs streamed for large files.

    ## Open questions / assumptions
    - Pagination/streaming thresholds to confirm.
