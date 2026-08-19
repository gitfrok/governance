# ADR-0080: Merge requests are durable, and the aggregate that carries them is scoped by whoever has the tenant

- **Status:** Accepted
- **Date:** 2026-08-20 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform
- **Related:** ADR-0071 (the same gap, closed for the repository registry), ADR-0062 (durable
  control-plane stores), ADR-0003 (tenancy and RLS), ADR-0007 (append-only audit), ADR-0025
  (module boundaries), ADR-0074 (the external issue references this now has to keep), ADR-0029
- **Governs:** the Code Review context's persistence. No PRD requirement — PR-9 already asks for the
  behaviour; this is about whether the behaviour survives a restart.

## Context

`cmd/dataplane-app` builds the Code Review context as `codereview.New(...)`, which is
`app.New(app.NewMemoryStore(), ...)`. **There is no Postgres adapter in the module at all.** Every
merge request, every review, every branch-protection rule, every ref revision this context was told
about, and — since T-0074 landed yesterday — every external issue reference is held in a map that
empties when the process does.

This is the gap ADR-0071 closed for the repository registry, in the same shape and for the same
reason: a port was defined, a memory adapter was written to get the surface working, and the durable
one was left for later. The registry's own comment said so for months before ADR-0071 acted on it,
and this module's `NewMemoryStore` says it now — *"Production injects a tenant-scoped database
store"* — describing an adapter that does not exist.

**What makes this worse than the registry's version of the same gap.** A repository registry that
emptied could be re-registered; the bare repositories were still on disk, and what was lost was a
record of which ones the product knew about. Here, what is lost is **the review itself**: who
approved what, at which revision, against which branch-protection rule. PR-9's loop is the product's
control story, and SPEC-0019 AC6 makes an accepted approval an audit record precisely because it is
evidence. The audit trail keeps the record of the approval act; the merge request that gives it
context does not survive a deploy.

**And T-0074 widened the exposure yesterday.** External issue references are a field on this
aggregate. A reference is inert by design, but it is also a statement — "this change is for that
issue" — that a reader will believe is kept. SPEC-0059's open question 1 recorded that it is not, and
recorded that fixing it needed its own ADR rather than a table quietly added to one adapter. This is
that ADR.

## The question this ADR exists to answer

Not *whether* to make it durable — ADR-0071 already decided that shape for this codebase. The real
question is **how the adapter learns which tenant a call is about**, because the port does not
consistently say.

Four of the eleven `Store` methods carry no tenant at all: `Get(id)`, `PutReview`, `Reviews`, and
`Seen(requestID)`. The port's comment covers this by asserting every method is *"tenant-scoped by the
caller passing an already-authorized context"* — which is true, and is not the same as the adapter
being able to scope a transaction. RLS needs a tenant on the connection before the statement runs.

Two obvious answers are both wrong:

- **Scope everything from `tenancy.FromContext`.** Breaks the event path. `platform/bus` does not put
  a tenant in the context, so `onRefUpdated` — which calls `SaveRefRevision`, `OpenForTarget`,
  `OpenForSource` and `Save` — would arrive unscoped and fail closed on every ref update.
- **Widen the port so every method takes a tenant.** Changes an interface with a working
  implementation and two years of call sites, to carry a value the caller already proved it had. It
  also invites the next adapter to trust the argument over the context, which is the direction
  SPEC-0042 AC5 spent a decision closing.

## Decision

**1. The adapter scopes from whichever source actually has the tenant, and refuses a disagreement.**
Where the port carries a tenant — as an argument, or as a field of the aggregate being written — that
is the scope, and a context naming a *different* tenant is refused before any statement runs. Where
the port carries none, the scope comes from `tenancy.FromContext`, and its absence is a refusal
rather than an unscoped query. This is `modules/repository/internal/adapters/postgres.scoped()`
generalised by one case, and the refusal is the same one SPEC-0042 AC5 requires: RLS protects one
tenant's rows from a transaction scoped to another, and has nothing to say about a transaction scoped
to the tenant a caller asked for.

**That this works at all is a property of the call sites, and it is checked rather than assumed.**
The four tenant-less methods are reachable only from request paths, where the gRPC door has already
called `tenancy.WithTenant`. The event path calls only methods that carry the tenant explicitly. A
test asserts that pairing, so a future caller that breaks it fails a test instead of a tenant.

**2. External issue references are a JSONB column on the merge request, not a child table.** They are
a *field of the aggregate*: loaded and saved as a unit, bounded at 25 by the domain, with identity
(`tracker`, `issue_key`) enforced above the store. Reviews get their own table because they have
their own port methods and their own lifecycle; references have neither. The bound is repeated as a
`CHECK (jsonb_array_length(external_issues) <= 25)`, because a column is the last place that can
still refuse.

**3. The version guard moves into the write.** `Save` becomes `UPDATE … WHERE version = $expected`,
and a zero-row update is reported as a conflict. The port's own comment says *"Every mutation is
guarded by it"*, and today that guard is a load-then-save race the memory store cannot lose because
it is single-process. A durable store on several plane replicas can, and finding out in production
that two reviewers' merges interleaved is not a way to learn this.

**4. The memory adapter stays, and a plane without a database still runs on it.** This follows the
repository registry's precedent rather than the release context's — Releases never had a memory
constructor because a record of what was announced that empties is worse than no record, while merge
requests, like the registry, predate durability and are used in dev without a database every day. The
constructor keeps its honest comment about what it costs.

**5. This does not reopen Phase 4.** Phase 4 is Complete, its exit criteria are met, and its plan
records what it deliberately did not deliver. Durability debt of this kind is not a surface, so it
gets its own epic rather than a retroactive edit to a closed phase.

## Accepted scope (2026-08-20)

**Accepted as written, all five decisions.** Specified as SPEC-0061, delivered by T-0078 in `backend`
only — no contract, no policy, no BFF, no frontend, because nothing a caller sees changes except that
it survives a restart.

One thing the acceptance fixes that the decisions left implicit: **the tables are the port's shape,
not the aggregate's.** Reviews, branch protections and ref revisions each have their own port methods
and their own keys, so each gets a table; the idempotency key and the `seen` request ID are both
"this was already applied" and share one. External issue references get neither — they are the JSONB
column of decision 2. That mapping is stated here so the migration is reviewable against a decision
rather than against whatever the adapter happened to need.

## What this does not decide

- **Retention of `seen` request IDs and idempotency keys.** Both grow without bound and nothing
  removes them. A follow-up, named below rather than solved here, because it is a data-lifecycle
  question like the one ADR-0076 decision 3 left open for repository deletion.
- **Anything on the wire.** No contract, no policy, no BFF, no frontend. The behaviour a caller sees
  is unchanged except that it survives a restart.
- **Whether reviews should be append-only.** `PutReview` replaces an actor's current review, which is
  what SPEC-0019 specified; making the history of superseded reviews durable is a different decision
  about what a review *is*.
- **Import records.** They already have their own store and their own durability question.

## Consequences

**Good.** The product stops losing its own review history on deploy. The external issue references
T-0074 added stop being a promise that survives one process lifetime. And the version guard the port
already claimed becomes true at the layer that can enforce it.

**Bad.** It is a large adapter — eleven methods, four tables — landing in one task, against a port
that was designed for a map. Some of the memory adapter's convenience (returning a whole aggregate
from a single map lookup) becomes a join, and the aggregate's read path gets slower in exchange for
existing after a restart.

**The risk this ADR is most likely to be wrong about.** Decision 1's hybrid. It is defensible today
because the call sites divide cleanly, and it is only one refactor away from not dividing cleanly —
a future caller that reaches `Get` from a bus handler would hit a refusal at runtime rather than a
compile error. The test in decision 1 is what converts that into a failure someone sees first, and if
it starts firing, the honest answer is to widen the port after all rather than to weaken the refusal.

## Alternatives considered

**Widen `Store` so every method takes a tenant.** Cleanest to read and refused above: it changes a
working interface to pass a value the caller already proved, and it makes the argument authoritative
over the verified context, which is the inversion SPEC-0042 AC5 closed.

**A child table for external issue references.** Keeps per-field `CHECK`s and makes a reference
individually addressable. Refused because nothing addresses one individually: link and unlink both
rewrite the aggregate, and four read sites would gain a join to reconstruct a field the domain treats
as a unit.

**Leave it in memory and document it.** It is documented — SPEC-0059 open question 1 — and that is
exactly what makes this ADR necessary rather than sufficient. A recorded gap that nobody closes is a
decision to accept the loss, and nobody has made that decision.

## Follow-ups

- Retention for `seen` request IDs and idempotency keys.
- Whether superseded reviews should be kept rather than replaced.
- Whether the Code Review context's read path needs a projection once merge requests are numerous —
  not a concern at current scale, and a real one if it ever is.
