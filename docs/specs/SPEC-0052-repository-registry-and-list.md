# SPEC-0052: A durable repository registry, and the list it makes possible

- **Status:** Approved (2026-08-18) — ADR-0071 Accepted; RED may begin
- **Owner:** platform
- **Context(s):** Repository (owns the registry and the listable set) · BFF (shapes) · Web frontend
  (renders) — ADR-0022
- **ADRs:** 0071 (decides this), 0070 (Tier B and the ordering law), 0003 (tenancy and RLS), 0062
  (the durability precedent), 0006 (the PDP), 0025, 0069
- **Task(s):** T-0053 (backend), T-0054 (contract + bff), T-0055 (web)

## Problem / context

PR-24: *a developer can list the repositories they may see, and only those; a repository they may
not see is not distinguishable from one that does not exist.*

Nothing in the tree can answer that today, and the reason is deeper than a missing route. The
Repository context's only `Store` adapter is `memstore` — a map that empties on restart — while the
repositories themselves are bare git repositories on block volumes that do not. No `repositories`
table exists in any migration. ADR-0071 records the finding and decides the shape.

The list is also the first surface where an empty answer is a **claim**. Every existing surface takes
a repository ID and asks about that one, so an empty registry yields a not-found for a specific
request, which SPEC-0001 wants to be indistinguishable from unauthorized anyway. A list that omits a
repository tells the reader it does not exist.

## In scope

- A Postgres `Store` adapter for the Repository context, behind the existing port.
- A `List` use case whose result is derived server-side from the caller's authorization.
- The `ListRepositories` RPC (additive), its BFF route, and the web landing page.

## Out of scope

- **Reconciling git storage into the registry** — ADR-0071 decision 3. A repository on disk with no
  registry row is absent from every surface here, by consequence rather than by defect.
- A create-repository path. Carried limit 17 stands; this spec does not close it.
- Repository settings, archival, visibility changes, or anything that writes to the registry beyond
  the existing `Create`.
- Sorting, filtering, or search over the list beyond paging. Ordering is the backend's.

## Contracts touched

`contracts/proto/repository/v1` — **additive**: a `ListRepositories` RPC and its request/response
messages. No existing message, field number or enum value changes.

## Data owned

The Repository context owns a new tenant-scoped `repositories` table: `tenant_id`, `repo_id`, `name`,
timestamps. Module-owned migration, RLS on `tenant_id`, no cross-context reads (ADR-0022).

## Acceptance criteria (each becomes a test)

### The durable store (T-0053)

- [x] **AC1** The Repository context persists through a process restart: a repository created, the
      store reconstructed against the same database, and the repository still loadable. The existing
      `Store` port is unchanged, so `app.Service` is untouched by the swap.
- [x] **AC2** The table is tenant-scoped with RLS, and the migration passes the boundary linter that
      fails a tenant table lacking `tenant_id` + RLS (T-0004).
- [x] **AC3** **Cross-tenant reads return absent, never forbidden.** A repository belonging to tenant
      B is not loadable, not listable and not countable by tenant A, and the refusal is
      indistinguishable from one that does not exist (invariant 1, SPEC-0001).
- [x] **AC4** `List` returns only what the PDP allows, derived server-side. The caller passes no
      repository set, filter or scope — there is no parameter for one. A test asserts a caller with
      no roles receives an empty list rather than an error, because "you may see none" and "there are
      none" must be the same answer.
- [x] **AC5** The list is paged by an opaque token, and carries **no total** — the same
      non-enumeration property code search has (SPEC-0035 AC3). A test asserts the response type has
      no field capable of expressing how many repositories the caller may not see.
- [x] **AC6** **The isolation proofs actually ran.** The suite reports zero skipped tests for this
      adapter's isolation and tenancy cases. Carried limit 5 means integration tests skip silently
      without `TEST_DATABASE_URL`, and a skipped isolation proof is not a proof — the exit record
      states the skip count it observed, not merely that the run was green.

### The wire and the BFF (T-0054)

- [x] **AC7** `ListRepositories` is additive: `buf breaking` passes against the previous contract,
      and no existing field number or enum value moves.
- [x] **AC8** `GET /v1/repositories` shapes and forwards only. Identity comes from the session; the
      request carries no tenant, actor, role or repository set, and there is no field for one.
- [x] **AC9** Every failure — dead session, PDP refusal, backend down — is the one coarse refusal
      that distinguishes nothing.

### The landing page (T-0055)

- [x] **AC10** `src/pages/index.astro` stops being the T-0001 stub and lists the caller's
      repositories, each linking to its tree.
- [x] **AC11** **An empty list never claims the tenant has no repositories.** The copy says what is
      true — that there is nothing here for this caller to see — and does not assert absence, in the
      same way SPEC-0049 AC4 governs the empty search page. A test enumerates the copy.
- [x] **AC12** No total or count is rendered. A refusal names no cause. Tokens gate at zero, units on
      every length, the two regression pins unmodified.
- [x] **AC13** The e2e stub serves the route with a populated list, an empty list, and a refusal;
      captures regenerated per SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | AC3 and AC5 together: RLS makes cross-tenant rows unreadable, and the absence of a total makes the count of what was withheld unexpressible. |
| G2 authorization | AC4 — the listable set is the PDP's, derived server-side, with no caller-assertable scope. |
| G5 auditability | Unchanged: `Create` already announces `RepositoryCreated`; listing is a read and adds no event. |

## Non-functional

- The adapter follows ADR-0062's shape: module-owned migration, RLS everywhere, no named exemption.
- `memstore` remains for unit tests. It must not be reachable from a plane binary's composition root.

## Open questions / assumptions

1. **Visibility equals the PDP's answer for `repo.read`**, evaluated per repository. If a future
   posture makes visibility coarser, that is a change to the PDP, not to this surface.
2. **A repository on disk with no registry row is invisible** (ADR-0071 decision 2). This is the
   RUNBOOK §8a recovery interaction with carried limit 17, and it is recorded, not solved.
3. The list is unsorted beyond whatever order the store returns; a stable order is a backend concern
   if it becomes one.
