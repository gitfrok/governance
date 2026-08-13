# T-0027: Scoped, read-only, time-boxed auditor access

- **Status:** Todo
- **Phase / Epic:** 2 / EP-13 Evidence & auditor access
- **Repo(s):** governance (policies) + backend + bff
- **Spec:** docs/specs/SPEC-0033-scoped-auditor-access.md — **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0006, 0007, 0003
- **Owner:** unassigned

## Goal
An external auditor is granted scoped, read-only, time-boxed access to evidence **without repo read
access** (PR-18). This is a distinct grant, not a role that happens to be able to read less.

## Acceptance criteria (test-first)
- [ ] AC1: an auditor grant is scoped to named evidence — a tenant, a date range, and the packs within
      it — and confers **no repository read**, proven by an auditor attempting a repo read and being
      denied and audited.
- [ ] AC2: the grant is **read-only**: every write path, including triage and policy authoring, is
      denied for an auditor principal.
- [ ] AC3: the grant is **time-boxed** and expires without an operator action; after expiry every
      evidence read is denied.
- [ ] AC4: granting, using, and expiring the grant are first-party audit events naming the granting
      admin and the auditor principal (ADR-0007).
- [ ] AC5: the grant is expressed in `governance/policies` and enforced by the PDP (ADR-0006), not by
      a UI role toggle.
- [ ] AC6: an auditor principal is tenant-scoped and cannot enumerate the existence of tenants,
      repositories, or packs outside the grant (SPEC-0001).
- [ ] AC7: revocation is immediate — a revoked grant fails the next read, not the next cache cycle
      (bundle-revision invalidation, SPEC-0002).

## Tests to write first
- policy (Rego): auditor grant allow/deny matrix — evidence read allowed, repo read denied, writes
  denied, expired grant denied.
- unit (backend): grant lifecycle — issue, use, expire, revoke.
- integration: auditor opens a T-0026 pack under a live grant; the same principal is denied a repo
  read and denied after expiry.
- policy/isolation: no enumeration outside the grant.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Depends on T-0026 having a pack to scope. The same **retention** gate applies: the audit retention
policy is an open ADR-0007 follow-up (PRD §12.3) and both PR-17 and PR-18 rest on it — a new decision
means a Proposed ADR and stop. Cross-repo changes land governance-first under ADR-0027.
