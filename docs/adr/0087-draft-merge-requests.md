# ADR-0087: A merge request can be a draft, and ready is its one door out

- **Status:** Accepted (2026-08-21, accepted as written by the deciding owner)
- **Date:** 2026-08-21
- **Deciders:** platform
- **Related:** SPEC-0019 (the state machine this extends), SPEC-0061/ADR-0080 (the durable
  aggregate carrying the new state), ADR-0085 (the floor a draft's merge would have to satisfy),
  ADR-0010 contracts additive-only (`contracts/README.md`)
- **Governs:** the Code Review state machine and `codereview/v1`. Additive within v1: one enum
  value, one request field, one RPC.

## Context

Opening a merge request today announces it: `MergeRequestOpened` publishes, attribution consumers
compute, the ref-update path projects onto it, and the merge gate will admit it the moment its
approvals land. There is no way to open a change early — to say "this is what I am doing" before
it is reviewable — without either triggering that machinery prematurely or keeping the change off
the platform entirely.

GitHub calls this a draft; GitLab calls it "mark as draft". The absence is felt in every flow
that starts a change before it finishes.

## Decision

**1. `DRAFT` joins the state machine as an additive enum value.** A draft is created by
`CreateMergeRequest` with `draft = true` (new field, default false keeps today's behaviour
byte-for-byte). It carries title, description, refs, revisions and version like any other merge
request.

**2. `MarkMergeRequestReady` is the one transition out.** New RPC, same command shape as merge:
opaque ID plus expected version for the optimistic pre-check. DRAFT → OPEN only; a merge request
in any other state is refused with the surface's coarse denial. Ready does not touch revisions:
they are re-read from what Repository/Git has announced at the moment of readiness, so a draft
opened against last week's target becomes reviewable against the current one.

**3. While DRAFT, the machinery stays quiet.** The open lookups the ref-update path projects
through select `state = 'OPEN'`, so a draft receives no projections and publishes no
`MergeRequestUpdated`; attribution consumers never see it; and `Merge` already refuses anything
not OPEN, so a draft cannot merge even by a stale client. Reviews may still be submitted against
a draft — early feedback is the point — but an approval pinned to a head revision that later
changes does not survive to the gate anyway (SPEC-0019 AC4).

**4. No new audit record for readiness.** Opening, reviewing and merging are audited because they
are accountability-bearing acts; marking a draft ready changes who can see the diff comfortably,
not who did what to the code. If evidence ever needs it, the decision-record trail already shows
the merge that could not have happened while it was a draft.

## Consequences

**Good.** Work can be shared before it is reviewable, and nothing downstream has to learn to
ignore half-finished changes — they were never announced.

**Bad.** Two states where there was one, and every reader of MR lists must now render DRAFT
honestly rather than lumping it into OPEN. The durable store takes the value as-is (the column is
text); the memory store likewise.

**The risk this ADR is most likely to be wrong about.** Readiness semantics: teams will ask for
auto-ready on approval, or ready-with-merge. Those are workflow conveniences over this foundation
and deliberately not decided here.

## Alternatives considered

**A boolean flag on an OPEN merge request.** One fewer state, and every consumer now branches on
a flag the state machine does not enforce — the merge refusal and the projection exclusion each
become "check the flag" instead of falling out of the state query. Refused.

**Keep drafts out of the platform until ready.** Preserves the single state by pushing the problem
onto branches nobody can see — which is exactly the visibility the feature exists to provide.
Refused.
