# SPEC-0031: Date-ranged evidence pack export

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Audit, Policy, Code Review, Security/Findings, Identity & Access
- **ADRs:** 0007, 0029, 0006, 0022
- **Task(s):** T-0026; T-0027 (consumer)
- **PRD:** PR-17

## Problem / context

The economic buyer's pain is assembling audit evidence by hand (PRD §2). PR-17 requires a compliance
owner to export a date-ranged pack — approvals, policy decisions, scan gates, access changes —
sufficient for a **SOC 2 Type II** control walkthrough, without engineer involvement.

This is the surface T-0018 owed forward. **SPEC-0011 AC14** — a criterion Phase 1 could not satisfy
because no evidence-pack surface existed — lands here, and ADR-0029 §4 binds this spec whether or not
the criterion is restated: a pack's control sections are a compliance claim, and admitting an attested
imported record makes that claim false to an auditor.

## In scope

- A pack generated for an explicit date range, with four control sections: approvals, policy
  decisions, scan gates, access changes.
- Exclusion of attested imported records from every control section, and a labelled appendix that
  carries attested history with its provenance blocks and the admitting `HistoryImported` event.
- Exclusion of dry-run decisions from control sections (SPEC-0029 AC2).
- Self-verifiability against the append-only chain (ADR-0007).
- Generation by a compliance owner through the product, PDP-authorized, tenant-scoped, and itself
  audited.

## Out of scope

- Auditor access grants and scoping (SPEC-0033) — this spec produces the pack; that one grants
  access to it.
- Compliance frameworks beyond SOC 2 Type II. They are deliberately unnamed (PRD §12.3); adding one
  changes this model and belongs in a PRD revision.
- Retention policy for the records a pack cites — see the blocking gate below.
- Findings, policy and review surfaces themselves (SPEC-0024…0030), which this spec reads.

## Data owned

Audit owns the immutable chain and the pack records it assembles. Policy owns decisions, Code Review
owns approvals and merges, Security/Findings owns scan gates, Identity & Access owns access changes.
Each section is assembled from its owning context's contract surface or an event-fed projection —
never by reading another context's tables (ADR-0022).

## Contracts touched

Additive export surface, specified in **SPEC-0032**.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A pack generated for an explicit date range contains the four control sections — approvals,
  policy decisions, scan gates, access changes — for that range and no other; a record outside the
  range appears nowhere.
- [ ] AC2 (**inherited from T-0018 AC19 / SPEC-0011 AC14, verbatim**): A generated evidence pack over
  a range spanning an import contains **zero attested records in its control sections**; attested
  history appears only in the labeled appendix with its provenance blocks and the admitting
  `HistoryImported` event.
- [ ] AC3: Every policy decision in the pack carries its **deciding policy version** and input digest
  (SPEC-0030 AC1), and a `DRY_RUN` decision never appears as an enforced control.
- [ ] AC4: An imported approval never appears as a control approval; it is display-only history in the
  appendix (ADR-0029 §4), consistent with SPEC-0029 AC6.
- [ ] AC5: A pack is produced by a compliance owner through the product surface — **no engineer
  involvement**, no operator-run script, no database access.
- [ ] AC6: Generation is PDP-authorized, tenant-scoped, and appends an immutable audit record; a pack
  cannot span two tenants (SPEC-0001).
- [ ] AC7: A pack is internally verifiable: a consumer can check each control record against the
  append-only chain and detect a record that does not belong, including a mutated one (ADR-0007).
- [ ] AC8: **Time-to-audit-evidence** is measured for a dated pack and reported in hours (PRD §8).
- [ ] AC9: AC2 is proven against a range that spans a **real T-0018 import**, not a synthesized one.
- [ ] AC10: A section whose source is incomplete for part of the range reports the gap explicitly; a
  pack never presents a partial section as complete.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | a pack is tenant-scoped and cannot span tenants |
| G2 least privilege | generation is a PDP decision and is itself audited |
| G5 auditability | the pack is assembled from, and verifiable against, the immutable chain |
| G6 compliance | control sections carry only witnessed first-party evidence; attested history is labelled and excluded (SPEC-0011 AC14) |
| G4 change governance | approvals and gates appear with the policy version that decided them |

## Non-functional

- Generation is asynchronous and observable per section, with record counts; a large range does not
  block interactive traffic.
- Assembly is reproducible: the same range over unchanged history yields the same pack content.
- Export volume counts against the tenant's fair-use dimensions rather than degrading normal traffic.

## Open questions / assumptions

- ~~**Blocking gate — retention.**~~ **Settled by ADR-0055 (Accepted 2026-08-14):** the chain never
  removes anything, so no cited control record can vanish beneath a pack; attested imported records
  live outside the chain and expire one year after import or with their repository; and **a pack is a
  self-contained snapshot**, embedding its records and anchors at generation time. AC7 therefore holds
  unconditionally, and an appendix stays readable after the attested history it quoted has aged out.
  ADR-0007's retention follow-up and SPEC-0011's last open item both close.
- **Pack format** (document, structured archive, or both) remains an implementation choice
  constrained by AC7 and by ADR-0055 rule 3 — whatever the format, a pack embeds its records and
  anchors rather than referencing them.
- **Assumption:** SOC 2 Type II control mapping is a product responsibility expressed in the section
  set above; a framework addition is a PRD revision, not a spec amendment.
- **Recorded deployment-posture limit (Phase-2 code review M13, 2026-08-14).** Pack assembly state is
  in-process only: requested packs are held in memory, and the idempotency reservations that by design
  stay registered forever do not survive a dataplane restart. A restart discards requested packs (they
  must be re-requested) and leaves a pack interrupted mid-assembly stuck in ASSEMBLING with no owner,
  since assembly runs on a detached context. **AC8** (time-to-evidence measured in hours) holds under
  this posture because the hours bound includes a re-request after restart in the single-tenant dev
  posture, and assembly remains reproducible for an unchanged range — but the limit is recorded rather
  than left silent. Follow-up: startup seeding or a persistent store for pack state and idempotency
  reservations. Recorded alongside the phase exit verdict
  (`../plans/phase-2-ultimate-wedge.md`, note (e)); this records a limit, not a decision — no ADR.
