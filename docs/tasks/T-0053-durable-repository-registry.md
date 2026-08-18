# T-0053: A durable repository registry — the Postgres store owed since T-0004

- **Status:** Done (2026-08-18) — backend@79479a8 + 0c853b1; SPEC-0052 AC1–AC6 proven
- **Phase / Epic:** 4 / EP-26 (Tier B — the PRD requires it, no route serves it)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0052-repository-registry-and-list.md (AC1–AC6)
- **ADRs:** 0071, 0003, 0062, 0025
- **Owner:** unassigned

## Goal

The Repository context's only store is a map. Its own header says the Postgres adapter was owed with
T-0004 and T-0010; both are Done and it never landed. Nothing above the port changes — this is the
adapter, and the `List` use case the registry makes answerable.

## Acceptance criteria (test-first)

- [x] AC1: the registry survives a process restart; the `Store` port is unchanged.
- [x] AC2: tenant-scoped table with RLS; the migration passes T-0004's boundary linter.
- [x] AC3: cross-tenant reads are absent, never forbidden — not loadable, listable or countable.
- [x] AC4: `List` returns the PDP's set, derived server-side; a caller with no roles gets an empty
      list, not an error.
- [x] AC5: paged by opaque token, with **no total** — no field can express what was withheld.
- [x] AC6: **the isolation proofs ran.** Zero skips for the tenancy and isolation cases; the exit
      record states the observed skip count.

## Tests to write first

- integration (real Postgres): save → reconstruct store → load, proving durability across the swap.
- integration: RLS — tenant A cannot read, list or count tenant B's rows.
- unit: `List` with a PDP that allows none, some and all; the empty case is a list, not an error.
- unit: the response type carries no total (a compile-level property, asserted by shape).
- boundary: the migration linter fixture still fails a tenant table without `tenant_id` + RLS.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **Carried limit 5 is the trap here.** Backend integration tests skip silently without
  `TEST_DATABASE_URL`, and the tests that skip are exactly AC3's isolation proofs. A green run with
  skips is not a proof; count them and say so.
- `memstore` stays for unit tests and must not be reachable from a plane binary's composition root.

## Exit record (2026-08-18)

**AC1–AC6 green, and AC6 is the one worth reading.** backend **79479a8** (registry + list) and
**0c853b1** (the RepositoryRegistry service).

**The isolation proofs failed on their first real run.** They had been passing as *skips*: carried
limit 5 means these tests skip silently without `TEST_DATABASE_URL`, and the six that skip are
exactly the cross-tenant proofs. Port-forwarded to the dev Postgres on :15432 they failed
immediately — a tenant ID derived from a long test name exceeded the platform's 64-character rule.
Fixed and re-run: **6/6 pass, 0 skips**, which is the only form in which AC6 is satisfied. A green
summary with six skips would have read identically in a report.

**The architecture fitness function refused the first design outright.** `List` needs an
authorization answer, so the service imported the Policy context — and Repository is a **leaf**,
pinned at fan-out zero by `TestFanCountsDescribeTheRealTree`. Everything depends on Repository and
it depends on nothing. The dependency now points the other way: `api.Authorizer` is declared in the
Repository context's own surface and the dataplane composition root adapts the PDP onto it. The
gate caught an architecture mistake, not a style one.

**Two properties are enforced by shape rather than by discipline.** `ListPage` has no total, and
`ListRepositoriesResponse` has no field that could carry one — a descriptor test fails the day
someone adds `total` or `repository_ids`. The page cursor encodes a position in the store's
**ordering**, not in the answer, so replaying one reveals nothing about what was refused along the
way; it is bound to the tenant that minted it and refused rather than reinterpreted when it arrives
from another.

**A caller the PDP allows nothing receives an empty list, never an error.** "You may see none" and
"there are none" have to be the same answer, or the difference between them is the disclosure PR-24
exists to prevent.
