# ADR-0055: Audit retention for attested imported records

- **Status:** Accepted
- **Date:** 2026-08-14
- **Governs:** G5 auditability, G6 compliance
- **Refines:** ADR-0007 (append-only audit log); **Relates to:** ADR-0029 (imported history &
  attested provenance), SPEC-0011, SPEC-0031, SPEC-0032, SPEC-0033

## Context

ADR-0029 fixes retention for **repository** data produced by an import. It does not fix retention for
the **audit** side, and ADR-0007 left retention and rotation as a later decision. SPEC-0011 recorded
this as its last open item, and the PRD carries it as a still-parked human decision (§12.3):
*retention of attested imported records — ADR-0029 says repo retention, not audit retention, but the
audit retention policy itself is still an ADR-0007 follow-up. Does not block T-0018; must be settled
before Phase-2 evidence export (PR-17/PR-18) relies on it.*

Phase 2 now relies on it. SPEC-0031 and SPEC-0032 produce a date-ranged evidence pack whose control
sections cite records from the append-only chain, and SPEC-0033 grants an external auditor scoped
read access to those packs. Three things become unanswerable without this decision:

1. **Can a cited record vanish beneath a pack?** A pack that cites a record a retention rule later
   removes is a false claim to an auditor, and SPEC-0032 AC7 requires every cited record to verify
   against the chain.
2. **How long must attested imported history be kept?** It is foreign, unwitnessed content admitted
   by a first-party `HistoryImported` event (ADR-0029). It lives in a labelled appendix and never in a
   control section (SPEC-0011 AC14, restated as SPEC-0031 AC2), so it carries a different evidential
   weight from a first-party record and may reasonably carry a different retention.
3. **What does "append-only" permit at end of life?** ADR-0007 forbids an update or delete path
   (invariant 5). Any retention rule that removes anything must say how removal is reconcilable with
   an immutable hash chain — for example by chain-preserving tombstones that keep verification intact
   — or must not remove at all.

This is a compliance and cost decision with a human owner. It is not a spec choice, and the
implementing tasks (T-0026, T-0027) must not invent it.

## Decision

Four rules, decided 2026-08-14.

### 1. The append-only chain never removes anything

First-party audit records — approvals, policy decisions, scan gates, access changes, and every other
chained event — are retained for the **life of the tenant**. There is no expiry, no rotation, and no
delete path. ADR-0007's invariant 5 stands unqualified, and no tombstone, sealed-segment or
chain-gap mechanism is built, because none is needed.

A verifier may therefore assume a **contiguous chain**. A gap is a defect, never a retention artifact.

### 2. Attested imported records are not in the chain, and carry their own retention

ADR-0029 already keeps attested content **out of** the append-only chain: an import is a first-party
chained event, and the attested history it admits is stored beside the chain, not within it
(SPEC-0011 AC5–AC7, AC12). Rule 1 therefore does not govern it, and expiring it introduces no delete
path into anything ADR-0007 protects.

Attested imported records are retained for **one year from import, or until the repository they were
imported into is deleted, whichever comes first**. They are appendix-only content that never
substantiates a control (ADR-0029 §4, SPEC-0011 AC14), so paying tenant-lifetime storage for them
buys no evidential weight.

The admitting `HistoryImported` event is a **first-party chained event** and is governed by rule 1: it
is retained for the life of the tenant, and it remains in the chain after the attested history it
admitted has expired. The record that an import happened therefore outlives the imported content.

### 3. An evidence pack is a self-contained snapshot

A generated pack **embeds** its control records, its labelled appendix, and its verification anchors
at generation time. It is not a view over the chain, and regenerating it is not required to read it.

Consequently a pack stays verifiable regardless of any later expiry: an appendix that quoted attested
history remains readable and verifiable after that attested history has aged out of its own store.
SPEC-0032 AC7 is satisfiable as written, unconditionally.

Packs are duplicated data and count against the tenant's fair-use storage dimension (PRD §6).

### 4. Neither period is tenant-configurable in v1

A tenant may not shorten or lengthen either retention. Rule 1 has nothing to configure, and rule 2's
one-year bound is a platform commitment rather than a tenant preference. A future data-minimization
requirement — a tenant asking for a shorter attested window, or a framework demanding a longer one —
is a **superseding ADR**, not a settings surface added under this one.

### The SOC 2 Type II floor is met with margin

A Type II examination covers a period of three to twelve months and looks back at evidence within it.
Rule 1 exceeds any such window by construction, and rule 3 makes an already-produced pack independent
of every later retention action. No framework floor constrains rule 2, because attested history is
never control evidence.

## Consequences

**Positive:** chain verification stays trivial and unconditional — a contiguous chain, no tombstone
semantics, no verifier that must accept a gap, and therefore no class of verifier bug that turns into
a false compliance claim. Every generated pack is verifiable forever, so SPEC-0032 AC7 holds without a
retention proviso and an auditor's copy never degrades. ADR-0007's retention follow-up and SPEC-0011's
last open item both close, and SPEC-0031/0032/0033 can be Approved.

**Negative:** audit storage grows without bound for the life of a tenant, on a dimension the PRD lists
under fair use (§6) but does not yet meter. Packs duplicate the records they cite, so a tenant that
exports frequently pays for that twice. Neither cost is measured today; measuring audit and pack
growth is the follow-up below. A tenant wanting a data-minimization posture over first-party audit
data cannot have one under this ADR — that is a superseding decision, not a configuration.

**Asymmetry to keep in mind:** the `HistoryImported` event outlives the attested history it admitted.
After a year, the chain still says an import happened, who admitted it, and what its provenance was,
while the imported review content may be gone. That is intended — the control claim is the event, not
the foreign content — but any UI or export that renders imported history must handle the absent case
rather than assuming the two live and die together.

**Follow-ups:** meter audit-store and evidence-pack growth against the PRD §6 fair-use dimensions; and
decide whether an expired attested store leaves a marker a reader can distinguish from "never
imported" (SPEC-0031's rendering concern, not a retention one).

## Alternatives considered

- **Chain-preserving tombstones with a fixed first-party period.** Bounds storage and permits data
  minimization, but requires a verifier that treats a gap as valid — and a verifier bug there is
  indistinguishable from tampering to an auditor. Rejected: the failure mode is a false compliance
  claim, which is exactly what this ADR exists to prevent.
- **Sealing and detaching cold chain segments.** Destroys nothing and bounds the hot store, at the
  cost of slow retrieval for an old pack. Rejected for v1 as premature: it is an optimization of rule
  1 that can be adopted later without changing any commitment made here.
- **One retention period for first-party and attested records alike.** Simplest to state, but pays
  tenant-lifetime storage for appendix-only content that never substantiates a control. Rejected.
- **A pack as a live view over the chain.** No duplication, but a pack silently loses citations when
  anything ages out, making SPEC-0032 AC7 conditional. Rejected.
- **Tenant-configurable retention.** Rejected for v1: rule 1 has nothing to configure, and a
  shortenable attested window is a data-minimization commitment that deserves its own ADR rather than
  a settings toggle.
- **Leave it to implementation.** Rejected: retention is a compliance commitment with a cost profile,
  not a default a task may pick, and ADR-0001 makes a new decision an ADR.
- **Fold it into ADR-0029.** Rejected: ADR-0029 is Accepted and governs repository data and
  provenance; extending an Accepted ADR by edit is forbidden, and this question is an ADR-0007
  follow-up rather than an ADR-0029 one.
