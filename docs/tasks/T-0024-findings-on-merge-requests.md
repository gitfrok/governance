# T-0024: Findings inline on the merge request

- **Status:** Done (2026-08-14) — contracts governance@6fa2a24; backend@c64e6a3; bff@47360c2; webfrontend@92804eb; AC4 recorded as a host limit against T-0003's cluster lane
- **Phase / Epic:** 2 / EP-11 Findings plane
- **Repo(s):** backend + bff + webfrontend
- **Spec:** docs/specs/SPEC-0028-findings-on-merge-requests.md — **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0015, 0005, 0012, 0022
- **Owner:** unassigned

## Goal
Findings appear inline in the merge request that **introduced** them (PR-15) — in the same place code
is reviewed, so a reviewer sees the finding without leaving the diff.

## Acceptance criteria (test-first)
- [x] AC1: a scan runs on a merge request and its findings are attributed to the change that
      introduced them; a finding that predates the MR is not attributed to it.
- [x] AC2: a finding renders inline at its location in the MR diff, and remains reachable when its
      line moves within the MR's subsequent pushes.
- [x] AC3: a finding already triaged as accepted or false-positive (T-0023) renders in that state
      rather than as new.
- [ ] AC4: scan results are visible on the MR **within one pipeline duration** (PRD §9 findings
      freshness), measured rather than asserted. *(host limit — see exit record)*
- [x] AC5: the MR surface is tenant-scoped and permission-filtered; the BFF aggregates only
      (invariant 18).
- [x] AC6: a scan that fails or times out is visible as such on the MR — it must not render as "no
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

## Exit record (2026-08-14)
Phase-2 exit task #23: attribution is set-difference by finding identity (head scan vs merge-base
scan), recomputed idempotently per (MR, head, base) and never an empty set — `UNAVAILABLE` with
reason when either side is missing. `GetMergeBase` added on `repository/v1` and served via
git-storaged. The webfrontend ships the three render states (attributed / triaged-distinctly /
UNAVAILABLE banner, never "no findings") with unit tests for all three (12 tests in
`mr-findings-render`). AC4 (freshness measured on a real pipeline) cannot be demonstrated while
CI scan dispatch needs the gVisor RuntimeClass the dev host lacks — recorded against T-0003's
cluster lane per this file's own note, not as a met criterion. The event-driven path the
measurement will observe there — ingest off `CIJobFinished` with pre-materialized attribution — is
**not yet built**: at the pinned backend no `CIJobFinished` subscriber exists and scan ingest is
RPC-only, so the `CIJobFinished`→ingest wiring is itself part of what the cluster lane must first
deliver, distinct from (and preceding) the scan-dispatch host limit above.

**Correction (2026-08-16).** The "not yet built" sentence above described the backend pinned when
this record was written and was overtaken days later: **T-0029 landed the wiring on 2026-08-14
(backend@49d6bfa), AC1–AC9 proven with tests** — `modules/security/internal/app/ci_ingest.go` is the
ingester, `cmd/dataplane-app/ciingest.go` subscribes `CIJobFinished` on the composition, and the
revision comes from `Jobs.Get`'s `CommitSHA` exactly as ADR-0059 Option C specifies. The sentence is
left standing rather than rewritten because it is part of a dated exit record; this correction is
what binds. AC4's blocker is therefore the **scan-dispatch host limit alone** (the gVisor
RuntimeClass the dev host lacks) plus T-0029's own AC10 end-to-end demonstration — not an unbuilt
path. Found while answering "what blocks the cluster lane"; the stale sentence had been read as
work the lane must still build.

Fix wave 2 (review H5/H6/L14, backend@42ad9b3): `ScanReportAt` spans every scanner class at the
revision and `ScanReport` carries its `ScanIDs` (H5); an attribution recompute replaces the cached
record so a later scan reaches the MR view and gate facts (H6); `UNAVAILABLE` carries the
resolver-not-composed reason (L14) — the wire enum still maps it to `UNSPECIFIED` until contracts
add the value (backlog carry-over). See `../plans/phase-2-ultimate-wedge.md`.
