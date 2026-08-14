# T-0015: Web: repo browser + file/diff view + command palette

- **Status:** Done (2026-08-14) — bff #22 + webfrontend #20 + super-repo #77, closed out at webfrontend@a44d1f1
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
- [x] AC2: a command palette provides quick navigation (ADR-0015). (Ctrl+K/Cmd+K, Browse tree /
      Open file / Compare revisions; arrow navigation, Enter and Escape land in webfrontend@2fa6ffe
      — see the note below.)
- [x] AC3: the app never calls `backend` directly (invariant 22). (`scripts/check-boundaries.sh`
      scans src/ for backend/infra imports and passes; the only upstream is `GITFROK_BFF_ORIGIN`.)

## Tests to write first
- Vitest units for components/data hooks; Playwright E2E for browse→file→diff.
- a test/lint asserting no direct backend calls (only BFF endpoints).

All three landed. `tests/command-palette-keyboard.test.tsx` (7 cases) covers the SPEC-0021 AC6
keyboard contract; `e2e/browse.spec.ts` (3 cases, Chromium, stub BFF) covers browse → file → diff,
the same journey by keyboard alone, and the coarse refusal a session-less request gets;
`tests/bff-client.test.ts` and `scripts/check-boundaries.sh` cover AC3. The BFF half of SPEC-0021
(AC2, AC3, AC5) is tested in `bff/internal/browser/handler_test.go`.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions

**What the review found (2026-08-14).** The task sat "In review" for four days with AC2 checked and
part of its criterion unbuilt: the palette opened on Ctrl+K/Cmd+K and closed on Escape, but SPEC-0021
AC6's arrow navigation and Enter were not implemented — the commands were anchors, reachable only by
Tab or mouse — and neither the keyboard tests nor the Playwright pass existed. Closing the task meant
building the missing half, not re-reading the old evidence. webfrontend@2fa6ffe adds the active-command
model (arrows wrap, Enter follows the active command's href, a listbox with `aria-selected` so the
highlight is announced), the seven keyboard cases, the three-case Playwright journey against a stub
BFF, and the CI step that runs it.

**Recorded substitution.** The E2E runs against `e2e/stub-bff.mjs`, not a live BFF: this repo's
contract is that every view renders from the BFF and the browser reaches nothing else, and a stub
proves exactly that while keeping the run hermetic. The session cookie travels as a request header
because Chromium will not accept a `__Host-` cookie over http, and weakening the production cookie to
suit a test would be the wrong trade.

Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
Cross-repo changes follow the ADR-0027 order (governance first).
