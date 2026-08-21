# SPEC-0064: Draft merge requests

- **Status:** Implemented (2026-08-21) — T-0081; contract, backend, bff and webfrontend proven.
  Approved (2026-08-21) under Accepted ADR-0087.
- **Owner:** platform
- **Context(s):** Code Review (state machine), contract `codereview/v1` (additive), BFF
  (passthrough), webfrontend (surface).
- **ADRs:** 0087 (decides this), 0019, 0080/0084 (the durable aggregate and its write split)
- **Task(s):** T-0081 (backend + bff + webfrontend)

## Problem / context

Opening a merge request announces it to every consumer. There is no way to share work in progress
without triggering attribution, projections and a merge gate that will admit it the moment one
approval lands.

## In scope

- `DRAFT` as an additive enum value; `draft = true` on create; `MarkMergeRequestReady`.
- Quiet machinery while DRAFT: no projections, no announcements, no merges.
- The surface: draft checkbox on open, DRAFT badge, mark-ready action.

## Out of scope

- Auto-ready on approval; ready-and-merge in one act (ADR-0087 names both as later workflow).
- Closing a draft (CLOSED exists on the enum; no surface writes it yet — unchanged).

## Acceptance criteria (each becomes a test)

- [x] **AC1** Creating with `draft = true` yields state DRAFT; the default (absent/false) yields
      OPEN exactly as before — the additive field changes nothing for existing callers.
- [x] **AC2** A draft cannot merge: the refusal is the same coarse denial any non-OPEN state
      gets, at the service edge before the PDP is asked.
- [x] **AC3** `MarkMergeRequestReady` moves DRAFT → OPEN under its own version bump, refuses a
      merge request in any other state, honours the expected-version pre-check with the same
      conflict error the other commands produce, and re-reads both revisions from what
      Repository/Git last announced.
- [x] **AC4** While DRAFT, a push to its target or source ref lands no projection on it and it
      appears in neither open lookup; after readiness, projections flow as for any OPEN merge
      request.
- [x] **AC5** Reviews can be submitted against a draft (early feedback is the point); an
      approval pinned to a head revision that changes before readiness does not count at the
      gate (SPEC-0019 AC4, unchanged).
- [x] **AC6** The durable store round-trips DRAFT unchanged (the column is text; no migration),
      and the wire carries the new enum value without altering existing field numbers.
- [x] **AC7** The web UI offers the checkbox on open, renders DRAFT as its own state — never
      folded into OPEN — and exposes mark-ready only on drafts.

## Governance mapping

| Objective | How |
|---|---|
| G4 review integrity | A draft cannot merge and is invisible to the gate until someone with authority marks it ready. |

## Open questions / assumptions

1. No event publishes on readiness this slice; consumers learn of the merge request when it
   merges or is read. If attribution needs earlier notice, an additive `MergeRequestReady` event
   is the follow-up — named here so it is one decision smaller.
