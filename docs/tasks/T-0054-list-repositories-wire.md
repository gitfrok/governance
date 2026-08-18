# T-0054: ListRepositories on the wire, and the BFF route

- **Status:** Todo
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** governance, bff
- **Spec:** ../specs/SPEC-0052-repository-registry-and-list.md (AC7–AC9)
- **ADRs:** 0071, 0070, 0022, 0049
- **Owner:** unassigned

## Goal

The additive contract change and the route that shapes it. Two repos, two commits, governance first
(API change → governance before consumers, invariant 21–25).

## Acceptance criteria (test-first)

- [ ] AC7: additive only — `buf breaking` passes; no existing field number or enum value moves.
- [ ] AC8: `GET /v1/repositories` shapes and forwards; identity from the session only; no
      caller-assertable tenant, actor, role or repository set, and no field for one.
- [ ] AC9: every failure is the one coarse refusal.

## Tests to write first

- contract: `buf breaking` against the previous contract; a fixture proving the check can fail.
- contract: the request message carries no tenant/actor/role/scope field (descriptor assertion, as
  SPEC-0043 AC6 does for residency).
- bff unit: a request that tries to assert scope is refused; the session is the only identity.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- Land the governance commit and bump the pin before the bff commit; the bff generates from
  `../governance/contracts`.
