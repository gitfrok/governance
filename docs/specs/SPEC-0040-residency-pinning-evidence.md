# SPEC-0040: Region and cloud pinning, demonstrable in the evidence pack

- **Status:** Draft
- **Owner:** platform
- **Context(s):** Control plane (declares and enforces) · Audit (evidences) — ADR-0022
- **ADRs:** 0009, 0010, 0029, 0055, 0060; SPEC-0031/0032 (evidence pack)
- **Task(s):** T-0033

## Problem / context

PR-22: tenant data and compute stay pinned to the tenant's declared region and cloud, and that
pinning is *demonstrable in the evidence pack*. Residency is G7 and it is the reason BYO exists
(PRD §4) — a claim a customer's auditor will ask us to prove, not describe.

Phase 2 built the evidence pack (SPEC-0031/0032) with control sections whose completeness is
asserted rather than assumed. Residency belongs there: a pack that cannot show where the work
happened is not evidence of residency, and a pack that shows it incompletely must say so.

## In scope

- A tenant's declared residency (cloud, region) as control-plane state, and where it is declared.
- Enforcement: refusing work that would place tenant data or compute outside the declaration.
- The residency section of an evidence pack: what it cites, and how a gap renders.

## Out of scope

- Multi-region or region migration for one tenant. A change of declared residency is not designed
  here; it needs its own decision.
- Air-gapped installs (PRD non-goal 1).
- Sub-region placement (zone) guarantees.

## Contracts touched

`contracts/proto/agent/v1` — additive: the data plane reports its cloud and region as observed facts.
Evidence-pack section types are governance-owned; a new residency section is an additive
`contracts/events/audit` / pack-contract change under its own PR.

## Data owned

The control plane owns the declaration and the registry of where each data plane actually runs. Audit
owns the pack. The data plane reports observed placement; it never declares its own residency —
observed and declared are different facts and the pack shows both.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A tenant's residency declaration (cloud, region) is control-plane state, server-recorded,
  and never asserted by a data plane or a request. A data plane reporting a placement that
  contradicts the declaration is a violation, not a redefinition.
- [ ] AC2: Placement is enforced, not just recorded: work that would place tenant data or compute
  outside the declared cloud/region is refused, and the refusal is audited with the declared and the
  attempted placement.
- [ ] AC3: A contradiction between declared and observed placement raises a visible violation state
  within a bounded detection window, and the window is configuration, not a compiled-in constant.
- [ ] AC4: An evidence pack over a date range carries a residency section citing the declaration in
  force during that range and the observed placement of every data plane that served the tenant.
- [ ] AC5: A range in which placement is unknown — no reports, a disconnected data plane, a gap in
  telemetry — renders as a gap with a reason, never as compliance. Absence of contradiction is not
  evidence of pinning (the SPEC-0031 AC10 rule, applied to residency).
- [ ] AC6: A declaration change inside the range is shown as a change with its effective time, not
  flattened to the current value. The pack answers "where was this tenant's work during the range",
  not "where is it now".
- [ ] AC7: The residency section is first-party evidence only. A customer-supplied attestation about
  their own cluster may appear in the attested appendix, never in a control section (ADR-0029 §4,
  SPEC-0031 AC2) — the pack must not let a customer attest their own compliance into the record.
- [ ] AC8: Cross-tenant isolation: a pack for tenant A contains no placement fact about tenant B,
  including through shared control-plane infrastructure.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | placement facts are tenant-scoped; no cross-tenant leakage through shared infra (AC8) |
| G6 evidence | residency is a pack section with honest gaps, not a claim in a document (AC4–AC6) |
| G7 residency | declared placement is enforced and contradiction is a visible state (AC2, AC3) |
| G3 auditability | refusals and violations are audited with both placements (AC2) |

## Non-functional

- Detection window and reporting interval are per-environment configuration (invariant 13).
- The residency section must not require reading the data plane at pack time: assembly uses recorded
  facts, so a pack is assemblable while a data plane is offline — the gap then renders per AC5.

## Open questions / assumptions

- Changing a tenant's declared residency (migration) is undesigned and out of scope here; today it
  would read as a change under AC6 with no mechanism to move existing data.
- Assumed: the control plane itself is not residency-pinned in Phase 3. If a customer requires the
  control plane in-region too, that is a topology decision beyond ADR-0009's split.
