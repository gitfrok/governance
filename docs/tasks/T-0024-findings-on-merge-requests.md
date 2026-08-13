# T-0024: Findings inline on the merge request

- **Status:** Todo
- **Phase / Epic:** 2 / EP-11 Findings plane
- **Repo(s):** backend + bff + webfrontend
- **Spec:** docs/specs/SPEC-0028-findings-on-merge-requests.md — **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0015, 0005, 0012, 0022
- **Owner:** unassigned

## Goal
Findings appear inline in the merge request that **introduced** them (PR-15) — in the same place code
is reviewed, so a reviewer sees the finding without leaving the diff.

## Acceptance criteria (test-first)
- [ ] AC1: a scan runs on a merge request and its findings are attributed to the change that
      introduced them; a finding that predates the MR is not attributed to it.
- [ ] AC2: a finding renders inline at its location in the MR diff, and remains reachable when its
      line moves within the MR's subsequent pushes.
- [ ] AC3: a finding already triaged as accepted or false-positive (T-0023) renders in that state
      rather than as new.
- [ ] AC4: scan results are visible on the MR **within one pipeline duration** (PRD §9 findings
      freshness), measured rather than asserted.
- [ ] AC5: the MR surface is tenant-scoped and permission-filtered; the BFF aggregates only
      (invariant 18).
- [ ] AC6: a scan that fails or times out is visible as such on the MR — it must not render as "no
      findings".

## Tests to write first
- unit (backend): introduction attribution — finding present before the MR, introduced by the MR,
  moved by a later push in the MR.
- contract: MR findings read surface against `governance/contracts`.
- integration: push → scan on MR → assert inline placement and freshness bound.
- unit (webfrontend): rendering of accepted / false-positive / failed-scan states.
- policy/isolation: a caller without MR read sees nothing.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Depends on T-0022 (identity) and T-0023 (triage state). Scans ride CI v0 (T-0017): the dev cluster has
no gVisor RuntimeClass under rootless podman, so **scan dispatch** may be demonstrable only on
T-0003's cluster lane. Record that as a host limit if it fires, not as a met criterion — Phase 1
recorded exactly this shape. Cross-repo changes land governance-first under ADR-0027.
