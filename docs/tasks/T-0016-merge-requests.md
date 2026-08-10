# T-0016: Merge requests + protected branches + approval policy

- **Status:** Done (2026-08-10) — backend #31/#33/#34/#35 + BFF/web minimal surface #24/#22
- **Phase / Epic:** 1 / MVP
- **Repo(s):** backend + governance (policies)
- **Spec:** docs/specs/SPEC-0009-merge-requests-approval.md; docs/specs/SPEC-0019-merge-request-contract.md
- **ADRs:** 0004, 0006, 0007
- **Owner:** unassigned

## Goal
Enable MR/PR review with protected branches and approval rules expressed as policy-as-code.

## Acceptance criteria (test-first)
- [x] AC1: open/review/merge an MR; a protected branch blocks direct pushes. (backend #31 MR
      lifecycle, #35 direct-push denial at the receive-pack PEP, #33/#34 authorized merge ref move.
      Web surface: bff #24 minimal MR HTTP routes, webfrontend #22 MR page.)
- [x] AC2: an approval policy (required reviewers) lives in `governance/policies` and is enforced by the PDP.
- [x] AC3: merges/approvals emit immutable audit events (ADR-0007). (`audit.MergeRequestApproved`/
      `MergeRequestMerged` published on the bus.)

## Tests to write first
- policy: Rego approval rules (allow/deny cases) in governance; integration: merge gating.
- unit (backend): MR state machine; audit: event emission.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
Cross-repo changes follow the ADR-0027 order (governance first).

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `d7be430` (#31) | MR lifecycle: open/review/merge state machine, review log, PDP gating, audit events |
| backend | `b67cf67` (#33) | Authorized merge ref move in storage (`MergeRef` CAS) |
| backend | `beab283` (#34) | Complete a merge through Repository/Git and serve the surface |
| backend | `eaaf95a` (#35) | Refuse a direct push to a protected ref before it lands (pre-receive interception) |
| bff | `4868697` (#24) | Minimal MR HTTP surface: GET an MR, POST create/review/merge, session-only identity |
| webfrontend | `9d29ad3` (#22) | Minimal MR page, SSR from the BFF only, links to the source→target diff |
