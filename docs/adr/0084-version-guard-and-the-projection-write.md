# ADR-0084: Save has two shapes, and the version guard can only guard one of them

- **Status:** Proposed
- **Date:** 2026-08-21
- **Deciders:** platform
- **Related:** ADR-0080 (the durable store this surfaces in), ADR-0071, SPEC-0061, T-0078
- **Governs:** the Code Review context's write protocol under the durable store. Nothing on the
  wire — no contract, no policy, no BFF, no frontend.

## Context

ADR-0080 decision 3 moved the version guard into the write: `Save` becomes
`UPDATE … WHERE version = $expected`, a zero-row update a conflict. SPEC-0061 AC9 repeats it, and
AC10 says the conflict surfaces as `api.ErrVersionConflict`, "the error the service already maps."

T-0078's RED, reviewed adversarially before commit, found that decision 3 left one conflict
implicit. The port has one write method, and the service uses it with **two protocols**:

- **Bumped writes.** `SubmitReview`, `Merge` and the other caller-editing paths read a merge
  request at version N, set `Version = N+1`, and `Save`. For these, `$expected = N` — the
  adapter's `WHERE version = mr.Version - 1` — is exactly AC9's guard: two writers reading N
  both arrive at N+1, one matches, one is told.
- **The projection write.** `Service.onRefUpdated` — the bus path — reads the open merge
  requests for a moved ref, sets `TargetRevision` or `HeadRevision`, and `Save`s **without
  bumping the version**. Deliberately: the service's own comment says a bump here would
  invalidate a review an author is mid-way through submitting, and the wire behaviour a caller
  sees (SPEC-0019's `ExpectedVersion` pre-check) depends on that staying true.

The guard fits the first shape and has **no correct value** for the second. The projection write
arrives with `mr.Version` equal to the stored version:

- `WHERE version = mr.Version - 1` matches nothing — every push to a ref with an open merge
  request conflicts, the projection never lands, and `MergeRequestUpdated` never publishes.
  This is not a race; it is the steady state.
- `WHERE version = mr.Version` cannot guard the bumped writers at all: they arrive with
  `mr.Version` one above the stored row, so the guard never matches them either — or, loosened
  to `IN (v-1, v)`, matches both concurrent bumped writers, and the loser silently overwrites
  the winner. AC9 dies quietly.

One statement cannot serve both shapes, because the two shapes disagree about what the version
column means: one advances it, the other preserves it. The memory store never surfaced the
disagreement because its `Save` is an unguarded map write.

The same review surfaced three findings that exist regardless of the decision below:

- **AC10's mapping is not in the code.** Every `Save` error in the service maps to
  `api.ErrDenied`; nothing maps a conflict to `api.ErrVersionConflict`. The task note's "the
  service already maps that error" is aspirational, not present.
- **`Merge`'s ordering becomes unsafe once `Save` can fail.** `MoveRef` runs before `Save`
  (service.go: the move names the target revision this context last saw). The memory store's
  `Save` could not fail, so the order was invisible; a durable `Save` that conflicts after the
  move leaves the ref merged and the merge request OPEN, with `Seen` burning the request ID so
  the retry returns the stale record.
- **`CreateOrGet`'s idempotency insert has no `ON CONFLICT`.** Two concurrent same-key calls
  both miss the lookup, one inserts, the other surfaces a unique violation as `ErrDenied` where
  the mutex-serialised memory store returned the winner. And AC7's call-site test hardcodes its
  event entry-point list and matches any receiver named `s` with a `.store` field — the import
  service already matches — so the pairing it asserts is narrower than it reads.

## The question this ADR exists to answer

How the durable write keeps AC9's guard for caller edits without breaking the version-preserving
projection write — without touching the wire, and without reopening ADR-0080's refusal to widen
the port for tenancy.

## Decision (proposed)

**1. The write splits along the protocol line that already exists.** `Save` keeps AC9's shape —
`UPDATE … WHERE version = mr.Version - 1`, zero rows a conflict — and serves the bumped writers
only. The projection path gets its own port method, version-preserving by construction: it
writes the projected fields (`TargetRevision`, `HeadRevision`) where the stored row is at the
version the event path read, advances nothing, and a zero-row update re-reads and re-applies
rather than surfacing a conflict a caller would have to interpret. **This is not a reopening of
ADR-0080's port-widening refusal**: that refusal was about carrying a tenant every caller
already proved, which inverted the context-over-argument posture; this method carries its
tenant exactly as every other event-path method does, and exists because two write protocols
genuinely exist, not to pass a value around.

**2. The conflict gets its error back.** Wherever the guarded `Save` fails on a zero-row
update, the service maps the adapter's conflict onto `api.ErrVersionConflict` — the wire shape
the pre-check already produces, so a caller sees one conflict error whether the race was caught
by the pre-check or by the write.

**3. `Merge` stops moving the ref before the record can refuse.** The guarded `Save` runs
before `MoveRef`: a conflict refuses the merge while nothing has moved. A `MoveRef` failure
after a successful `Save` is then the remaining hazard — the record says merged, the ref did
not move — and the SPEC-0061 amendment must name its compensation (a re-open with its own
version bump and a named audit record) rather than leaving it to the implementer mid-RED. The
memory posture had this hazard in neither direction because its `Save` could not fail; the
durable posture forces the choice, and the choice belongs to the spec.

**4. The idempotency insert converges instead of denying.** `CreateOrGet` inserts the
idempotency row `ON CONFLICT DO NOTHING` and reads back, so a concurrent double-submit returns
the winner's merge request exactly as the memory store did.

**5. AC7's test derives its entry points.** The event entry-point list comes from the bus
subscription call sites rather than a hardcoded name, and the store-call selector is qualified
by receiver type, so the import service's identically-shaped field stops matching.

## Alternatives considered

**The event path bumps the version like every other writer.** No port change, one uniform
guard — and a wire change: a push would invalidate a review mid-submission, which the service's
own comment exists to prevent and SPEC-0061's wire-unchanged rule forbids. Refused.

**`WHERE version IN (v-1, v)`.** Both shapes pass — and two concurrent bumped writers both
pass too: the loser matches the winner's just-bumped row and overwrites it, version intact,
AC9 silently dead. Refused by demonstration, not by taste.

**An unconditional overwrite (the memory-store semantics, kept).** The event path keeps
working and AC9 never existed. Refused: AC9 is the decision ADR-0080 made, and a durable store
on several plane replicas is exactly where the load-then-save race stops being theoretical.

**Amend SPEC-0061 without an ADR.** The amendment is mechanical once the write splits, but the
split is a decision about what the port means — one write method, two protocols — and decisions
live here, not in a spec diff (ADR-0001).

## Consequences

**If accepted.** SPEC-0061 is amended: AC9 names the bumped writers; a new criterion covers the
projection write and its re-read-on-conflict; AC10 names the mapping; `Merge`'s ordering and its
compensation get their own criterion; the AC7 test's shape is restated. T-0078's RED resumes on
the amended spec. The backend work-in-progress — adapter, migration, call-site test, wiring —
stays uncommitted until then; its scoping, schema and durability proofs passed review and
real-Postgres runs unchanged by this decision.

**While proposed.** T-0078 stops. Nothing commits, nothing merges, and the durable store the
product is still losing on every restart stays lost until this is decided — the cost of the
stop is named rather than implied.

## What this does not decide

- Anything on the wire. The caller sees one conflict error and one projection behaviour, both
  unchanged in shape.
- Whether the projection write belongs on the port or on a second interface the service holds.
  That is the amendment's drafting detail, not the decision.
- Retention, superseded reviews, read projections — ADR-0080's follow-ups, undisturbed.
