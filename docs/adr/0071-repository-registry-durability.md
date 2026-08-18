# ADR-0071: The repository registry is durable, and it is the product's truth for existence

- **Status:** Accepted
- **Date:** 2026-08-18 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform (found while scoping PR-24, ADR-0070 Tier B)
- **Supersedes / superseded by:** —
- **Related:** ADR-0003 (tenancy and RLS), ADR-0062 (durable control-plane stores — the precedent
  this follows), ADR-0025 (modular monolith), ADR-0033 (repo storage is block volumes), ADR-0070
  (the route-before-pixel law that made this visible), ADR-0022 (bounded contexts)
- **Governs:** PR-24 (the repository list), and every future surface that answers "which
  repositories exist"

## Context

PR-24 requires that a developer can list the repositories they may see. Scoping it surfaced
something no governance document records:

**The Repository context has never had a durable store.** `modules/repository/internal/adapters/`
contains exactly one adapter, `memstore`, and its own header says why:

> *It exists so the plane binary and the tests can be wired end-to-end before the Postgres adapter
> lands with the tenancy baseline (T-0004) and the Git-RPC service (T-0010).*

Both of those tasks are Done. The Postgres adapter never landed. There is no `repositories` table in
any module's migrations — the only `CREATE TABLE ... repositories` in the tree is a fixture under
`internal/arch/testdata/`, which exists to prove the migration linter fires.

So the registry that records *which repositories exist* is a `map` that empties when the process
restarts, while the repositories themselves are bare git repositories on block volumes (ADR-0033)
that do not. The two disagree after every restart, and nothing reconciles them.

This has been survivable because nothing reads the registry as a list. Every existing surface takes
a repository ID from the caller and asks about that one, so an empty registry produces a not-found
for a specific request — indistinguishable from an unauthorized one, which is what SPEC-0001 wants
anyway. **A list is different.** A list that omits a repository asserts that it does not exist, to a
caller who may be looking straight at its clone URL.

There is a second, already-recorded interaction. Carried limit 17 (`HANDOFF.md`): git/v1 has no
create-repository RPC, and bare repos are created out-of-band by the RUNBOOK §8a `kubectl exec`
recovery. Those repositories never enter the registry at all, durable or not.

## Decision

**1. The Repository context gets a Postgres store adapter behind its existing `Store` port.** A
tenant-owned `repositories` table with `tenant_id` and RLS, an additive module-owned migration, and
the same shape ADR-0062 gave the agent and residency stores. The port does not change, so nothing
above it changes: this is the adapter that was owed since T-0004.

**2. The registry is the product's truth for existence.** A repository is listed when the registry
holds a row for it, not when a directory exists on a volume. A bare repository on disk with no
registry row is **absent from the product's surfaces by consequence, not by defect** — it was
created outside the product's write path, and the product does not claim to know about it.

This is the sentence that keeps the next operator from filing a bug: recover a repository with the
RUNBOOK §8a procedure and it will not appear in the list until something registers it.

**3. Nothing reconciles disk into the registry, and that is deliberate for now.** A backfill that
walked storage and invented registry rows would make the product assert ownership, naming and tenancy
it was never told. If a reconciliation is wanted, it needs its own decision about where those facts
come from. Recorded as a follow-up rather than built.

**4. The listable set is derived server-side by the PDP.** The caller sends no repository list, no
filter and no scope. This follows the code-search precedent (SPEC-0034 AC9): the searchable set is
derived at query time, and the BFF and the web frontend filter nothing. A repository the caller may
not see is absent from the answer, and absent is indistinguishable from non-existent — which is PR-24
as written and G1 as ADR-0003 means it.

## Consequences

**Good.** The registry stops disagreeing with reality across a restart. The list can be built without
shipping a landing page that goes blank after one, and the same durability now backs every future
answer to "which repositories exist" — settings, admin, and anything Tier C adds.

**Bad.** A new tenant-owned table and migration to own, and the Repository context acquires a real
persistence dependency it has not had. Every test that relied on a store with no setup cost now needs
the real-Postgres harness, which — carried limit 5 — **skips silently without `TEST_DATABASE_URL`.**
An isolation proof that skips is not an isolation proof, and this is the first place in the phase
where that distinction bites.

**The risk this ADR is most likely to be wrong about.** Decision 3. Refusing to reconcile is right
in the sense that the product should not invent facts, and wrong in the sense that an operator who
recovers a repository now has an invisible one, with no path to make it visible short of a create
through the product's own write path — which, per carried limit 17, does not exist as an RPC. The
honest position is that limit 17 and this decision are the same problem seen from two sides, and
neither is closed by this ADR.

## Alternatives considered

**List from git storage rather than from the registry.** Would show recovered repositories and needs
no new table. Refused: storage knows paths, not tenancy, ownership or names, so the product would
have to infer them — and inferring tenancy is the one inference invariant 1 exists to forbid.

**Ship the list on the memstore and record the limit.** Cheapest, and refused on the phase's own
terms: a list that omits existing repositories is a false non-existence claim, which is the failure
class this phase has spent three surfaces eliminating — the truncated pack that read as complete, the
empty search page that read as "nothing exists". The front door is the worst place to reintroduce it.

**Reconcile disk into the registry on startup.** Rejected as decision 3 explains: it makes the
product assert tenancy and ownership nobody told it.

## Follow-ups

- A create-repository path through the product (carried limit 17). Until it exists, the RUNBOOK §8a
  recovery is the only way a bare repository appears, and those stay invisible to the registry.
- Whether a reconciliation between storage and registry should exist, and what would authorise the
  facts it would have to invent.
- The memstore adapter stays for tests; a fitness check that keeps it out of a plane binary's
  composition root would make that a property rather than a convention.
