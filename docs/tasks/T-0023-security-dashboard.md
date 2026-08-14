# T-0023: Unified security dashboard + triage state

- **Status:** Done (2026-08-14) — contracts governance@bcd37c9; backend@acb4a9c; bff@d290e14; webfrontend@5b53c36
- **Phase / Epic:** 2 / EP-11 Findings plane
- **Repo(s):** backend + bff + webfrontend
- **Spec:** docs/specs/SPEC-0026-security-dashboard-triage.md; docs/specs/SPEC-0027-triage-dashboard-contract.md — both **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0015, 0006, 0007, 0022
- **Owner:** unassigned

## Goal
One dashboard showing all findings for a repository and for an org, filterable by severity, class,
age, and owning team, with triage state that survives a re-scan (PR-14). ADR-0015 makes the unified
surface a design rule: findings consolidate here rather than scattering into per-feature tabs.

## Acceptance criteria (test-first)
- [x] AC1: one dashboard lists all findings for a repository and for an org, across every scanner
      class ingested by T-0022.
- [x] AC2: results are filterable by **severity, class, age, and owning team**, in combination.
- [x] AC3: a finding can be triaged as **accept, false-positive, fix, or defer**, and the triage state
      **survives a re-scan** — proven by re-scanning and asserting the state is still attached to the
      same finding identity.
- [x] AC4: a triage transition is authorized by the PDP and emits an immutable audit event naming the
      actor (ADR-0006, ADR-0007) — it is a control action, not a UI preference.
- [x] AC5: the dashboard is tenant-scoped and permission-filtered — a caller sees findings only for
      repositories they may read; no count, filter facet, or aggregate reveals a finding on a
      repository they cannot read.
- [x] AC6: the BFF aggregates only — no business logic (invariant 18); triage rules live in backend.
- [x] AC7: the surface meets ADR-0015's interaction bar (progressive disclosure, keyboard-reachable
      filters) rather than adding a dense per-scanner tab set.

## Tests to write first
- unit (backend): triage state machine; re-scan reattachment by finding identity.
- contract: dashboard read surface against `governance/contracts`; BFF aggregation shape.
- unit (bff): aggregation only — assert no domain logic.
- policy/isolation: a caller without read on a repository sees no finding, no count, and no facet
  derived from it.
- integration: ingest → triage → re-scan → assert triage survives.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Depends on T-0022's identity rule; do not start before its contract is merged in `governance/`.
Aggregate leakage (AC5) is the easy defect here — a count that changes with an unauthorized
repository's findings leaks existence just as a list does. Cross-repo changes land governance-first
under ADR-0027, then backend → bff → webfrontend.

## Exit record (2026-08-14)
Phase-2 exit task #23: triage is keyed by finding identity in a separate versioned table, so
re-scan survival is structural (no reattachment code) — the ingest→triage→re-scan integration
asserts state survives. AC5 holds via authorization-inside-the-query summary/facet reads with the
differential two-principal leak tests; byte-identical responses for no-match vs unauthorized-only.
Web dashboard (org + repo surfaces) ships in webfrontend@5b53c36 with the triage actions and
justification flow; BFF stays shape-only under the boundary fitness tests. All suites green at the
exit pins (backend full suite with `TEST_DATABASE_URL`, bff, webfrontend check/test/build).

Fix wave 2 (review H3 + L17, backend@42ad9b3): `GetFinding`/`GetTriage` now refuse cross-repository
reads inside a tenant (mirroring `SetTriage`, SPEC-0026 AC6 / SPEC-0027 AC3–AC4), and findings
cursors are bound to the issuing actor. See `../plans/phase-2-ultimate-wedge.md`.
