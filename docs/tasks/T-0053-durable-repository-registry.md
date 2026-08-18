# T-0053: A durable repository registry — the Postgres store owed since T-0004

- **Status:** Todo
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

- [ ] AC1: the registry survives a process restart; the `Store` port is unchanged.
- [ ] AC2: tenant-scoped table with RLS; the migration passes T-0004's boundary linter.
- [ ] AC3: cross-tenant reads are absent, never forbidden — not loadable, listable or countable.
- [ ] AC4: `List` returns the PDP's set, derived server-side; a caller with no roles gets an empty
      list, not an error.
- [ ] AC5: paged by opaque token, with **no total** — no field can express what was withheld.
- [ ] AC6: **the isolation proofs ran.** Zero skips for the tenancy and isolation cases; the exit
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
