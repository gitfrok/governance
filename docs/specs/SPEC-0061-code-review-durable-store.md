# SPEC-0061: The Code Review context keeps what it was told

- **Status:** Approved (2026-08-20) — ADR-0080 Accepted as written; RED may begin
- **Owner:** platform
- **Context(s):** Code Review only. No contract, no policy, no other module.
- **ADRs:** 0080 (decides this), 0071 (the same gap closed for the registry, and the adapter shape
  this reuses), 0062 (durability), 0003 (tenancy and RLS), 0025, 0074 (the references this keeps)
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
- A Postgres adapter filling the existing `Store` port, wired when the plane has a pool.
- The version guard moved into the write.
- Real-Postgres proofs for durability, isolation and the version conflict.

## Out of scope

- **Any change to the port, the contract, the policy bundle, the BFF or the frontend.** What a caller
  sees is unchanged except that it survives a restart.
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

- [ ] **AC1** A merge request opened through the service is readable by a **new** store over the same
      database — the restart, expressed as the only thing a test can express it as.
- [ ] **AC2** Reviews, branch protections and ref revisions survive the same way, and a merge
      request's external issue references come back in the order they were linked, with their
      tracker, key, URL, linker and instant intact.
- [ ] **AC3** `CreateOrGet` is idempotent across store instances: the same idempotency key returns the
      first merge request and reports that it created nothing, after a rebuild.
- [ ] **AC4** `Seen` reports a request ID as unseen exactly once, and that survives a rebuild too.
      This is the guard that stops a replayed write from applying twice, so a store that forgot it
      would replay every write a client retried across a restart.

### Scoping — ADR-0080 decision 1

- [ ] **AC5** Where the port carries a tenant, that is the scope, and a **context naming a different
      tenant is refused before any statement runs** — the SPEC-0042 AC5 posture, which RLS cannot
      provide because the transaction would be scoped to the tenant that was asked for.
- [ ] **AC6** Where the port carries no tenant — `Get`, `PutReview`, `Reviews`, `Seen` — the scope
      comes from `tenancy.FromContext`, and **its absence is a refusal, not an unscoped query**.
- [ ] **AC7** **The call-site pairing is asserted, not assumed.** A test walks the service's own call
      sites and fails if a tenant-less store method is reachable from the event path, or if the event
      path calls one. ADR-0080 records this as the risk it is most likely to be wrong about; this is
      the test that makes being wrong visible.
- [ ] **AC8** A merge request, review, protection or ref revision belonging to another tenant is
      **absent**, not forbidden: no method returns it, and none reports that it exists.

### The version guard — ADR-0080 decision 3

- [ ] **AC9** `Save` writes `UPDATE … WHERE version = $expected` and reports a zero-row update as a
      conflict rather than as success. Two writers reading the same version and both saving: one
      wins, one is told.
- [ ] **AC10** The conflict is reported as the error the service already maps to
      `api.ErrVersionConflict`, so the wire behaviour a caller sees is unchanged.

### The schema

- [ ] **AC11** Every table carries `tenant_id`, RLS **enabled and forced**, and one `tenant_isolation`
      policy keyed on `tenant_id`; the migration passes T-0004's boundary linter and carries the
      `-- rls: tenant-key=tenant_id` marker the lint reads.
- [ ] **AC12** Grants are minimal: the application role gets `SELECT, INSERT, UPDATE` and **no
      `DELETE`** on any table — nothing in the port deletes, and a grant that exists is a capability
      somebody eventually uses.
- [ ] **AC13** `external_issues` is JSONB with `CHECK (jsonb_array_length(external_issues) <= 25)`,
      repeating the domain's bound at the column, and defaults to an empty array so a merge request
      with no references is not a null.
- [ ] **AC14** A migration test asserts the above as text, so the privilege surface is reviewed where
      it is declared rather than remembered.

### Composition

- [ ] **AC15** The plane wires the durable store when it has a pool and the memory store when it does
      not, and the memory constructor keeps its comment about what that costs (ADR-0080 decision 4).
- [ ] **AC16** **The isolation proofs ran.** Zero skips for the tenancy cases; the exit record states
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
