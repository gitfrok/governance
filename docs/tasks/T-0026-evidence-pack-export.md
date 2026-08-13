# T-0026: Date-ranged evidence pack export

- **Status:** Todo
- **Phase / Epic:** 2 / EP-13 Evidence & auditor access
- **Repo(s):** backend + bff
- **Spec:** docs/specs/SPEC-0031-evidence-pack-export.md; docs/specs/SPEC-0032-evidence-export-contract.md — both **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0007, 0029, 0006
- **Owner:** unassigned

## Goal
A compliance owner exports a date-ranged evidence pack — approvals, policy decisions, scan gates,
access changes — sufficient for a **SOC 2 Type II** control walkthrough, **without engineer
involvement** (PR-17). This task **owns T-0018's AC19**, the criterion Phase 1 owed forward.

## Acceptance criteria (test-first)
- [ ] AC1: a pack is generated for an explicit date range and contains the four control sections —
      approvals, policy decisions, scan gates, access changes — for that range and no other.
- [ ] AC2 (**inherited from T-0018 AC19 / SPEC-0011 AC14, verbatim**): a generated evidence pack over
      a range spanning an import contains **zero attested records in its control sections**; attested
      history appears only in the labeled appendix with its provenance blocks and the admitting
      `HistoryImported` event.
- [ ] AC3: a policy decision in the pack carries the **deciding policy version** (T-0025 AC1); a
      dry-run decision is never presented as an enforced control.
- [ ] AC4: the pack is produced by a compliance owner through the product surface — **no engineer
      involvement**, no script run by an operator (PRD PR-17).
- [ ] AC5: generation is authorized by the PDP, tenant-scoped, and itself audited; the pack cannot
      span two tenants (SPEC-0001).
- [ ] AC6: the pack is internally verifiable — a consumer can check that its control sections come
      from the append-only chain (ADR-0007) and detect a record that does not.
- [ ] AC7: **time-to-audit-evidence** is measured for a dated pack and reported in hours (PRD §8).
- [ ] AC8: proven against a range that really spans an import produced by T-0018, not a synthesized
      one.

## Tests to write first
- integration: generate a pack over a range spanning a real T-0018 import; assert zero attested
  records in every control section, and that attested history appears only in the labeled appendix
  with provenance blocks and the `HistoryImported` event.
- unit (backend): section assembly; dry-run exclusion; policy-version carry-through.
- contract: export surface against `governance/contracts`; BFF aggregation only (invariant 18).
- policy/isolation: unauthorized export denied and audited; cross-tenant range impossible.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
**Blocking gate — retention of attested imported records.** ADR-0029 fixes *repository* retention,
not *audit* retention; the audit retention policy is an open **ADR-0007 follow-up** and the last open
item from SPEC-0011 (PRD §12.3). This task may design and build against the criteria above, but must
not ship an export whose retention behavior that decision would contradict. A new decision means a
**Proposed ADR in `governance/` and stop** (ADR-0001, ADR-0002).

ADR-0029 §4 binds this surface whether or not the criterion is copied into the implementing work:
a pack's control sections are a compliance claim, and admitting an attested record makes that claim
false to an auditor. Depends on T-0025 for policy-decision records and on T-0022/T-0024 for scan
gates. Compliance frameworks beyond SOC 2 Type II are deliberately unnamed (PRD §12.3) — adding one
changes this model and belongs in a PRD revision.
