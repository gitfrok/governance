# SPEC-0032: Evidence export contract

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Audit, Policy, Code Review, Security/Findings, Identity & Access
- **ADRs:** 0007, 0029, 0006, 0022, 0032
- **Task(s):** T-0026; T-0027 (consumer)
- **PRD:** PR-17

## Problem / context

SPEC-0031 requires a date-ranged, self-verifiable evidence pack whose control sections admit no
attested imported record, and leaves the boundary unspecified. Without a contract, Audit would read
four other contexts' tables to assemble sections, the BFF would decide what belongs in a control
section, or a caller would name the records to include. This specification defines the additive
boundary before implementation.

## In scope

- An additive Audit surface for requesting a pack over a date range, observing its assembly, and
  retrieving it.
- The section model, its record shape, and the appendix that carries attested history.
- Verification data that lets a consumer check a pack against the append-only chain.
- The reviewed action vocabulary this adds.

## Out of scope

- Auditor grants and scoped access (SPEC-0033), which authorize *reading* a pack.
- The producing surfaces themselves (SPEC-0027, SPEC-0030, SPEC-0019, Identity & Access), which this
  contract consumes.
- Any caller-supplied record set, section membership, or authorization outcome.

## Contracts touched

A **new** `contracts/proto/audit/v1` package. Audit has carried events only
(`contracts/events/audit/v1`) through Phase 1; evidence export is its first RPC surface, so the
package is created here rather than extended:

- `RequestEvidencePack`, `GetEvidencePackStatus`, and `GetEvidencePack`.
- Every request carries required context: tenant ID, verified actor ID, verified actor roles, request
  ID. A caller cannot assert actor or roles. Cross-tenant or empty context is a coarse denial.
- `RequestEvidencePack` accepts only a closed date range and optional repository scope. It does
  **not** accept a record list, a section filter that could omit an unfavourable control record, or a
  retention override. Assembly is server-determined; idempotent per tenant, range and request ID.
- A pack carries four **control sections** — approvals, policy decisions, scan gates, access changes —
  and one **labelled appendix** for attested imported history. A control-section record carries its
  chain position, actor, resource, action, outcome, timestamp, and — for a policy decision — bundle
  revision, input digest and mode. `mode = DRY_RUN` is not representable in a control section.
- An attested record is representable **only** in the appendix, together with its provenance blocks
  and the admitting `HistoryImported` event, and is labelled as foreign history. The control-section
  message has no field capable of carrying an attested record, so exclusion is a type property, not a
  filter applied at assembly time.
- The pack carries verification data: per-section chain anchors sufficient to re-derive that each
  cited record is in the append-only chain and that no cited record was mutated (ADR-0007).
- A section that could not be fully assembled carries an explicit gap marker with its bounds; a pack
  cannot represent a partial section as complete.

Additive events: `EvidencePackRequested` and `EvidencePackCompleted`, carrying opaque identifiers,
tenant scope, range bounds and section counts — never record contents, source, or provenance bytes.

The policy follow-up adds this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `evidence.pack.generate` | `tenant` | range bounds, repository scope |
| `evidence.pack.read` | `evidence_pack` | tenant, range bounds, pack state |

Range bounds, section counts and pack state are facts produced by Audit; none is a caller claim.

## Data owned

Audit owns packs, their sections, verification anchors, idempotency keys and its event payloads. Each
producing context owns its records and exposes them through its own contract surface or an event-fed
projection; Audit reads no other context's tables (ADR-0022).

## Acceptance criteria (each becomes a test)

- [ ] AC1: A compliance-owner principal requests a pack for a closed range, observes assembly, and
  retrieves it; replaying a request ID is idempotent and produces no second pack or audit record.
- [ ] AC2: The control-section message cannot carry an attested record — proven by a contract test on
  the schema, not only by an assembly test — and attested history is representable only in the
  labelled appendix with provenance blocks and the `HistoryImported` event.
- [ ] AC3: A `DRY_RUN` policy decision is not representable in a control section and is absent from
  every generated pack.
- [ ] AC4: A caller cannot supply a record set, omit a section, or assert a pack's contents; such a
  request is rejected rather than partially honoured.
- [ ] AC5: Every operation is tenant-scoped; a cross-tenant request, status read, retrieval or event
  consumption is a coarse denial that does not distinguish nonexistent from unauthorized.
- [ ] AC6: Generation and retrieval are PDP decisions with server-derived context, and generation
  appends exactly one immutable audit record correlated to the decision ID.
- [ ] AC7: A consumer verifies every cited control record against the chain anchors and detects a
  mutated or non-chain record.
- [ ] AC8: An incompletely assembled section carries an explicit gap marker with bounds.
- [ ] AC9: `buf lint` and `buf breaking` are green; all additions are additive within v1 and
  generated-code freshness is green at the composition boundary (ADR-0032, T-0020).
- [ ] AC10: Boundary tests prove Audit assembles sections through contracts or projections only, and
  that the BFF performs no assembly, filtering, or authorization.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | packs, requests and events are tenant-scoped |
| G2 least privilege | generation and retrieval are PDP decisions; no caller-shaped content |
| G5 auditability | packs are chain-verifiable and their generation is itself audited |
| G6 compliance | attested exclusion is a type property of the schema, so the control claim cannot silently degrade |
| G9 least-privilege footprint | events carry counts and identifiers, never record contents or provenance bytes |

## Non-functional

- Assembly is asynchronous, resumable, and observable per section with record counts.
- Retrieval of a large pack is streamed and bounded; no operation loads a full pack into memory.
- Denial and not-found errors do not distinguish nonexistent, cross-tenant and unauthorized packs.

## Open questions / assumptions

- ~~**Retention gate.**~~ **Settled by ADR-0055 (Accepted 2026-08-14):** no cited control record can
  vanish, and a pack embeds its records and anchors (rule 3), so AC7 is satisfiable as written. The
  pack message must therefore carry embedded records, not references — a v1 schema property.
- **Pack serialization format** is unset pending SPEC-0031's approval-time decision; AC7's
  verifiability requirement constrains it.
- ~~**Package creation.**~~ **Settled at approval (2026-08-14):** Audit's first RPC surface is the
  new `contracts/proto/audit/v1` package, not an `evidence/v1` one, alongside SPEC-0025's
  `security/v1` and SPEC-0035's `search/v1`.
- **Assumption:** access changes are sourced from Identity & Access through its own contract surface.
  If no such surface exists at implementation time, adding one is part of T-0026, not a reason to
  read its tables.
