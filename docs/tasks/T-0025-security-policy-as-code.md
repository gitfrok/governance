# T-0025: Security & approval policy — authored, versioned, dry-run, enforced at merge

- **Status:** Todo
- **Phase / Epic:** 2 / EP-12 Policy-as-code
- **Repo(s):** governance (policies) + backend
- **Spec:** docs/specs/SPEC-0029-security-approval-policy.md; docs/specs/SPEC-0030-policy-decision-provenance-contract.md — both **Approved 2026-08-14** (reading A: governance-PR authoring); RED may start (AGDD)
- **ADRs:** 0006, 0007, 0029, 0015
- **Owner:** unassigned

## Goal
A security or approval policy can be authored, versioned, dry-run, and enforced at merge, with the
**deciding policy version recorded on the decision** (PR-16). Builds on the Phase-0 PDP (SPEC-0002)
and the Phase-1 merge gate (T-0016); adds scan findings as a gating input.

## Acceptance criteria (test-first)
- [ ] AC1: a policy is authored and **versioned**; every decision records the policy version that
      decided it, and that version is retrievable later from the decision record.
- [ ] AC2: a policy can be **dry-run** against real history — it reports what it *would* have decided
      without enforcing, and a dry-run decision is distinguishable from an enforced one in the audit
      chain.
- [ ] AC3: a security policy blocks a merge on a finding that violates it (e.g. severity threshold),
      and the block is a PDP decision, not UI logic (ADR-0006, invariant on server-side enforcement).
- [ ] AC4: an approval policy composes with T-0016's protected-branch enforcement rather than
      replacing it; both are enforced server-side.
- [ ] AC5: an **imported approval never satisfies** a policy requirement — only first-party approvals
      gate a merge (ADR-0029 §4). Proven by a merge attempt whose only approval is imported.
- [ ] AC6: a policy change invalidates every cached decision by construction — invalidation is by
      **bundle revision**, not by clock (SPEC-0002's answered open question).
- [ ] AC7: every enforced decision emits an immutable audit event carrying the actor, the input
      digest, the outcome, and the policy version (ADR-0007).

## Tests to write first
- policy (Rego): allow/deny cases per policy class; severity-threshold gating on findings.
- unit (backend): decision record shape — policy version, dry-run flag, input digest.
- integration: dry-run over history produces no enforcement and no gate; enforce blocks the merge.
- integration: merge with only an imported approval is denied (ADR-0029 §4).
- unit: cache invalidation on bundle-revision change.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Depends on T-0022 for the findings a security policy reads. AC4 of Phase 0's SPEC-0002 stands: the
authorization fitness function is a **tripwire, not a proof** — authorization logic has no import
signature, so it catches obvious shapes only; do not treat a green fitness run as evidence here.
Cross-repo changes land governance-first under ADR-0027.
