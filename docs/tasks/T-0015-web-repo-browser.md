    # T-0015: Web: repo browser + file/diff view + command palette

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** webfrontend
    - **Spec:** docs/specs/SPEC-0008-web-repo-browsing.md
    - **ADRs:** 0015, 0023
    - **Owner:** unassigned

    ## Goal
    Ship the GitHub-clean repo browsing UX consuming only the BFF.

    ## Acceptance criteria (test-first)
    - [ ] AC1: browse tree, view a file, and view a diff, served via SSR from the **BFF** only.
- [ ] AC2: a command palette provides quick navigation (ADR-0015).
- [ ] AC3: the app never calls `backend` directly (invariant 22).

    ## Tests to write first
    - Vitest units for components/data hooks; Playwright E2E for browse→file→diff.
- a test/lint asserting no direct backend calls (only BFF endpoints).

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
