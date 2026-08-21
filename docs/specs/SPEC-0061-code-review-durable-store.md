# SPEC-0061: The Code Review context keeps what it was told

- **Status:** Implemented (2026-08-21) — T-0078 Done at backend@06e14da; AC1–AC18 proven, 16
  real-Postgres proofs green with `-race` and 0 skips. Approved (2026-08-20) — ADR-0080 Accepted as
  written; **amended 2026-08-21** by Accepted ADR-0084 (the Save-shape conflict): the write splits
  along its protocol line, the conflict's error and `Merge`'s ordering get their criteria, and the
  AC7 test's shape is restated. RED resumed on the amended spec.
- **Owner:** platform
- **Context(s):** Code Review only. No contract, no policy, no other module.
- **ADRs:** 0080 (decides this), 0084 (amends it — the write split), 0071 (the same gap closed for
  the registry, and the adapter shape this reuses), 0062 (durability), 0003 (tenancy and RLS),
  0025, 0074 (the references this keeps)
- **Task(s):** T-0078 (backend)

## Problem / context

`cmd/dataplane-app` builds the Code Review context on `app.NewMemoryStore()` and the module has no
Postgres adapter. Merge requests, reviews, branch-protection rules, ref revisions, idempotency keys
and external issue references are all lost when the process restarts.

ADR-0080 decided the shape. This spec builds it, and its acceptance criteria spend most of their
words on the two things that can go wrong quietly: **a query that runs unscoped**, and **a write that
lands on a version the caller did not read**.

## In scope

- A `codereview` schema with the tables ADR-0080's accepted scope names, RLS on every one.
- A Postgres adapter filling the `Store` port, wired when the plane has a pool.
- The version guard moved into the write — and the write split along its protocol line
  (ADR-0084 decision 1): guarded `Save` for bumped writers, a version-preserving projection
  method for the event path.
- Real-Postgres proofs for durability, isolation and the version conflict.

## Out of scope

- **Any change to the contract, the policy bundle, the BFF or the frontend.** What a caller sees
  is unchanged except that it survives a restart. The port itself gains exactly one method — the
  projection write of ADR-0084 decision 1 — and only this context's service calls it; that is not
  a wire change.
- **Import records**, which have their own store and their own durability question.
- **Retention of `seen` request IDs and idempotency keys** (ADR-0080 follow-up).
- **Keeping superseded reviews.** `PutReview` replaces, as SPEC-0019 specified.
- **A read projection.** Not a concern at this scale, and inventing one here would be speculative.

## Data owned

Schema `codereview`, all tenant-scoped with RLS enabled and forced:

| Table | Key | Why it is its own table |
|---|---|---|
| `merge_requests` | (tenant_id, merge_request_id) | the aggregate; carries `external_issues` as JSONB |
| `reviews` | (tenant_id, merge_request_id, actor_id) | its own port methods; one current review per actor |
| `branch_protections` | (tenant_id, repository_id, target_ref) | exact-ref rule, its own port methods |
| `ref_revisions` | (tenant_id, repository_id, ref) | what Repository/Git last announced |
| `applied_requests` | (tenant_id, request_id) | idempotency keys and `seen` request IDs are the same fact: this was already applied |

## Acceptance criteria (each becomes a test)

### Durability

- [x] **AC1** A merge request opened through the service is readable by a **new** store over the same
      database — the restart, expressed as the only thing a test can express it as.
- [x] **AC2** Reviews, branch protections and ref revisions survive the same way, and a merge
      request's external issue references come back in the order they were linked, with their
      tracker, key, URL, linker and instant intact.
- [x] **AC3** `CreateOrGet` is idempotent across store instances: the same idempotency key returns the
      first merge request and reports that it created nothing, after a rebuild. It also converges
      under a concurrent double-submit: the idempotency insert is `ON CONFLICT DO NOTHING` followed
      by a read-back (ADR-0084 decision 4), so the loser returns the winner's merge request exactly
      as the mutex-serialised memory store did, instead of surfacing a unique violation.
- [x] **AC4** `Seen` reports a request ID as unseen exactly once, and that survives a rebuild too.
      This is the guard that stops a replayed write from applying twice, so a store that forgot it
      would replay every write a client retried across a restart.

### Scoping — ADR-0080 decision 1

- [x] **AC5** Where the port carries a tenant, that is the scope, and a **context naming a different
      tenant is refused before any statement runs** — the SPEC-0042 AC5 posture, which RLS cannot
      provide because the transaction would be scoped to the tenant that was asked for.
- [x] **AC6** Where the port carries no tenant — `Get`, `PutReview`, `Reviews`, `Seen` — the scope
      comes from `tenancy.FromContext`, and **its absence is a refusal, not an unscoped query**.
- [x] **AC7** **The call-site pairing is asserted, not assumed.** A test walks the service's own call
      sites and fails if a tenant-less store method is reachable from the event path, or if the event
      path calls one. Its event entry points are derived from the bus subscription call sites rather
      than a hardcoded name list, and its store-call selector is qualified by receiver type, so an
      identically-shaped field on another service does not match (ADR-0084 decision 5). ADR-0080
      records this as the risk it is most likely to be wrong about; this is the test that makes being
      wrong visible.
- [x] **AC8** A merge request, review, protection or ref revision belonging to another tenant is
      **absent**, not forbidden: no method returns it, and none reports that it exists.

### The version guard — ADR-0080 decision 3, split by ADR-0084

- [x] **AC9** `Save` serves the **bumped writers only** — `SubmitReview`, `Merge` and every other
      caller-editing path that reads version N and sets `Version = N+1` before saving — and writes
      `UPDATE … WHERE version = $expected`, `$expected = N`, reporting a zero-row update as a
      conflict rather than as success. Two writers reading the same version and both saving: one
      wins, one is told.
- [x] **AC10** **The projection write is its own port method**, version-preserving by construction
      (ADR-0084 decision 1). It writes the projected fields (`TargetRevision`, `HeadRevision`)
      where the stored row is at the version the event path read, advances nothing, and a zero-row
      update re-reads and re-applies rather than surfacing a conflict a caller would have to
      interpret. Every push to a ref with an open merge request lands its projection and publishes
      `MergeRequestUpdated`, exactly as before the durable store.
- [x] **AC11** The conflict is reported as `api.ErrVersionConflict`: wherever the guarded `Save`
      fails on a zero-row update, the service maps the adapter's conflict onto it (ADR-0084
      decision 2) — the wire shape the `ExpectedVersion` pre-check already produces, so a caller
      sees one conflict error whether the race was caught by the pre-check or by the write.
- [x] **AC12** **`Merge`'s ordering, and its compensation** (ADR-0084 decision 3). The guarded
      `Save` runs before `MoveRef`, so a conflict refuses the merge while nothing has moved. A
      `MoveRef` failure after a successful `Save` is compensated by a re-open — the merge request
      returns to OPEN under its own version bump — and the compensation is a named audit record,
      so a retry does not find a MERGED record pointing at a ref that never moved.

### The schema

- [x] **AC13** Every table carries `tenant_id`, RLS **enabled and forced**, and one `tenant_isolation`
      policy keyed on `tenant_id`; the migration passes T-0004's boundary linter and carries the
      `-- rls: tenant-key=tenant_id` marker the lint reads.
- [x] **AC14** Grants are minimal: the application role gets `SELECT, INSERT, UPDATE` and **no
      `DELETE`** on any table — nothing in the port deletes, and a grant that exists is a capability
      somebody eventually uses.
- [x] **AC15** `external_issues` is JSONB with `CHECK (jsonb_array_length(external_issues) <= 25)`,
      repeating the domain's bound at the column, and defaults to an empty array so a merge request
      with no references is not a null.
- [x] **AC16** A migration test asserts the above as text, so the privilege surface is reviewed where
      it is declared rather than remembered.

### Composition

- [x] **AC17** The plane wires the durable store when it has a pool and the memory store when it does
      not, and the memory constructor keeps its comment about what that costs (ADR-0080 decision 4).
- [x] **AC18** **The isolation proofs ran.** Zero skips for the tenancy cases; the exit record states
      the observed skip count (carried limit 5).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | RLS on all five tables, plus the pre-statement refusal AC5 requires; another tenant's row is absent. |
| G4 review integrity | The review record survives the process. An approval's audit record already outlived it; now so does the merge request that gives it meaning. |
| G5 auditability | Nothing changes about what is audited. What changes is that the thing the audit record points at is still there. |

## Non-functional

- The adapter is one round trip per port method where the memory store was one map lookup. That is
  the price of existing after a restart, and this context's call volume is a review loop rather than
  a hot path.

## Open questions / assumptions

1. **`applied_requests` and the idempotency table grow without bound.** ADR-0080's follow-up. Naming
   it here so the first person to notice the table's size finds it recorded rather than surprising.
2. **The hybrid scoping holds because the call sites divide cleanly.** AC7 is what turns a future
   refactor that breaks the division into a failing test rather than a runtime refusal.
3. **A plane without a pool still loses everything on restart**, exactly as today. That is decision 4,
   and it is a dev convenience rather than a supported production posture.
