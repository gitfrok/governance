# T-0015: Web: repo browser + file/diff view + command palette

- **Status:** In review (2026-08-10) — code complete on bff #22 + webfrontend #20 + super-repo #77; awaiting review
- **Phase / Epic:** 1 / MVP
- **Repo(s):** webfrontend
- **Spec:** docs/specs/SPEC-0008-web-repo-browsing.md; docs/specs/SPEC-0021-browser-view-contract.md
- **ADRs:** 0015, 0023, 0049
- **Owner:** unassigned

## Goal
Ship the GitHub-clean repo browsing UX consuming only the BFF.

## Acceptance criteria (test-first)
- [x] AC1: browse tree, view a file, and view a diff, served via SSR from the **BFF** only.
      (webfrontend #20: tree/file/diff/raw routes call the SPEC-0021 BFF surface; bff #22 serves it.)
- [x] AC2: a command palette provides quick navigation (ADR-0015). (Ctrl+K/Cmd+K, focus-trapped,
      Browse tree / Open file / Compare revisions.)
- [x] AC3: the app never calls `backend` directly (invariant 22). (`scripts/check-boundaries.sh`
      scans src/ for backend/infra imports and passes; the only upstream is `GITFROK_BFF_ORIGIN`.)

## Tests to write first
- Vitest units for components/data hooks; Playwright E2E for browse→file→diff.
- a test/lint asserting no direct backend calls (only BFF endpoints).

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
Cross-repo changes follow the ADR-0027 order (governance first).
