# T-0054: ListRepositories on the wire, and the BFF route

- **Status:** Done (2026-08-18) — governance@1534a70, backend@0c853b1, bff@1c52899; SPEC-0052 AC7–AC9 proven
- **Phase / Epic:** 4 / EP-26
- **Repo(s):** governance, bff
- **Spec:** ../specs/SPEC-0052-repository-registry-and-list.md (AC7–AC9)
- **ADRs:** 0071, 0070, 0022, 0049
- **Owner:** unassigned

## Goal

The additive contract change and the route that shapes it. Two repos, two commits, governance first
(API change → governance before consumers, invariant 21–25).

## Acceptance criteria (test-first)

- [x] AC7: additive only — `buf breaking` passes; no existing field number or enum value moves.
- [x] AC8: `GET /v1/repositories` shapes and forwards; identity from the session only; no
      caller-assertable tenant, actor, role or repository set, and no field for one.
- [x] AC9: every failure is the one coarse refusal.

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

## Exit record (2026-08-18)

**AC7–AC9 green.** governance **1534a70**, backend **0c853b1**, bff **1c52899**.

**The first contract commit put the RPC on the wrong service, and the tree said so.** `cef052f`
added `ListRepositories` to `RepositoryReader` — which is served by **git-storaged**, a process that
reads bare repositories off block volumes and holds no record of which repositories the product
knows about. ADR-0071 makes the registry, in the data plane, the truth for existence. The RPC was on
the process that cannot answer it. Corrected in `1534a70` to a second service, `RepositoryRegistry`,
before anything was generated from it; still additive, `buf breaking` green against `origin/main`.

`ListContext` exists rather than reusing `ReadContext` because `ReadContext` carries a
`repository_id` and a list has no repository to name. Reusing it would have left a field a caller
could populate to mean something the server must then ignore — and a field that must be ignored is
worse than no field, because someone eventually stops ignoring it.

**The BFF drops any repository the session carried** before forwarding, so nothing downstream can
begin honouring one. The empty list is a `200` with an empty array and the test asserts the exact
body: the one case here that is not a refusal is the one that looks most like one.
