    # SPEC-0008: Web repo browsing UX (browser + diff + palette)

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** webfrontend
    - **ADRs:** 0015, 0023
    - **Task(s):** T-0015

    ## Problem / context
    Ship the GitHub-clean repo browsing experience consuming only the BFF.

    ## In scope
    - SSR repo browser: tree, file view, diff view; a command palette for navigation.

    ## Out of scope
    - Editing/review UI (later phase).

    ## Contracts touched
    Consumes the BFF view API (generated TS types from `governance/contracts`).

    ## Data owned
    No data owned; presentation only.

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: Browse tree, view a file, and view a diff, served via SSR from the **BFF only**.
- [ ] AC2: A command palette provides quick navigation (ADR-0015).
- [ ] AC3: The app never calls `backend` directly (invariant 22) — enforced by test/lint.

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G2 least privilege | UI relies on BFF/PDP decisions |
| (UX) | ADR-0015 clean surface |

    ## Non-functional
    First-contentful-paint within budget; accessible (keyboard/pallette).

    ## Open questions / assumptions
    - Exact palette command set to refine with design.
