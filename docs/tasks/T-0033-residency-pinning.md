# T-0033: Residency pinning and its evidence-pack section

- **Status:** Done (2026-08-15) — governance@0e61302, backend@c630a1e; SPEC-0040 AC1–AC8 proven;
  recorded limits below
- **Phase / Epic:** 3 / EP-17 (residency and evidence)
- **Repo(s):** governance (pack-contract addition, ADR-0027 order), then backend
- **Spec:** docs/specs/SPEC-0040-residency-pinning-evidence.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0009, 0010, 0029, 0055
- **Owner:** unassigned

## Goal
Make residency provable: a declared cloud/region enforced on placement, contradictions visible, and
a pack section that answers "where was this tenant's work during the range" with honest gaps.

## Acceptance criteria (test-first)
SPEC-0040 AC1–AC8. The ones that decide whether this is evidence or decoration:
- [x] AC5: an interval with no placement reports renders as a gap, never as compliance.
- [x] AC7: a customer's own attestation about their cluster can reach the attested appendix only,
      never a control section — a customer must not attest their own compliance into the record.
- [x] AC6: a declaration change inside the range shows as a change with its effective time.

## Tests to write first
- unit: declared-vs-observed contradiction detection inside the window; gap rendering for a silent
  interval.
- contract: the additive pack section against `buf breaking`.
- integration: pack assembled while a data plane is offline — assembles, with the gap.
- policy-isolation: no tenant-B placement fact in a tenant-A pack, including through shared infra.

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony — evidence and tenancy.

## Notes / open questions
Changing a tenant's declared residency (migration) is undesigned: today it renders as a change with
no mechanism to move existing data. Say so in the exit record rather than letting the section imply
migration is supported.

## Exit record (2026-08-15)

Implemented test-first and merged, ADR-0027 order: governance main at **0e61302** (additive
`SECTION_TYPE_RESIDENCY=5`, `GAP_REASON_PLACEMENT_SILENT=4`, `ResidencyFactKind`, and the
`residency.declaration.set` policy action), backend main at **c630a1e** (`modules/residency`, the
agent `PlacementGate` on enrolment, and the evidence-pack residency section).

**SPEC-0040 AC1–AC8, one line of proof each:**

- **AC1** — the residency declaration is control-plane state, server-recorded, never asserted by a
  data plane or a request; placement is CP-observed only.
- **AC2** — placement is enforced at enrolment: an enrolment whose reported placement contradicts
  the declaration is refused **coarsely, without spending the token**, and the refusal is audited.
- **AC3** — a declared-vs-observed contradiction raises a visible violation state within a bounded
  detection window that is configuration, not a compiled-in constant — contradictions are witnessed.
- **AC4** — a date-ranged pack carries a residency section citing the declaration in force during the
  range and the observed placement of every data plane that served the tenant.
- **AC5** — an interval with no placement reports (silence) renders as a **gap with a reason, never
  as compliance**.
- **AC6** — a declaration change inside the range is shown as a change with its effective time, never
  flattened to the current value.
- **AC7** — customer self-attestation is excluded **by construction**: wire-parity, appendix
  isolation, and reflect type-property tests together keep a customer's own attestation out of every
  control section.
- **AC8** — cross-tenant isolation: a pack for tenant A carries no placement fact about tenant B,
  including through shared control-plane infrastructure; refusals are coarse.

**Recorded limits:**

- **The declaration store is in-memory.** It is lost on a control-plane restart; the audit trail
  remains durable, so the declaration is reconstructable from the record, but the live store does not
  survive the restart.
- **Declare has no wire/RPC surface in Phase 3.** The declaration is set by in-process composition
  only; a wire surface is future work (tracked in `../backlog/`).
- **Migration is undesigned.** Changing a tenant's declared residency renders as a change under AC6
  with no mechanism to move existing data — stated here so the section never implies migration is
  supported (SPEC-0040's out-of-scope).

**New environment configuration (invariant 13):** `GITFROK_RESIDENCY_DETECTION_WINDOW` and
`GITFROK_RESIDENCY_MAX_REPORT_INTERVAL`. Both are fail-safe unset: with no value they read as `0`,
which renders the **whole window as a gap** rather than assuming compliance — operators must set them
for complete packs.
