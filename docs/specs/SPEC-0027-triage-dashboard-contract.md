# SPEC-0027: Triage and dashboard-read contract

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Security/Findings, Identity & Access, Policy, Audit
- **ADRs:** 0015, 0006, 0007, 0022, 0032
- **Task(s):** T-0023; T-0024, T-0026 (consumers)
- **PRD:** PR-14

## Problem / context

SPEC-0026 requires a consolidated dashboard and durable triage, and leaves the boundary unspecified.
Without a contract, the BFF would compute filter semantics, a consumer would read Security/Findings'
tables to learn a triage state, or triage would be written onto the finding message — which SPEC-0025
forbids. This specification defines the additive boundary before implementation.

## In scope

- An additive Security/Findings surface for triaging a finding, reading its triage history, and
  querying findings for a repository or an org with filters, counts and facets.
- Triage as a **separate resource keyed by finding identity**, so it is unaffected by re-scan.
- Additive triage events for later Phase-2 consumers.
- The PDP action vocabulary for triage and dashboard reads.

## Out of scope

- Ingestion (SPEC-0025), MR placement (SPEC-0028), gating (SPEC-0030), evidence export (SPEC-0032).
- Browser routes; the BFF aggregates this surface and holds no domain logic.
- Any authorization outcome or filtered result asserted by a caller, a BFF, or an event payload.

## Contracts touched

Additive operations on `contracts/proto/security/v1`:

- `SetTriage`, `GetTriage`, `ListFindings` (extended with dashboard filters), and
  `GetFindingsSummary` for counts and facets.
- Every request carries required context: tenant ID, verified actor ID, verified actor roles, request
  ID. Actor and roles come from authenticated identity; a caller cannot assert them. Empty or
  cross-tenant context is a coarse denial.
- A **triage record** is its own message: opaque triage ID, the finding identity it is keyed to,
  tenant and repository scope, state (`ACCEPT`, `FALSE_POSITIVE`, `FIX`, `DEFER`), bounded
  justification text, actor, timestamp, and a server-assigned positive version. **The finding message
  gains no triage field** — SPEC-0025's statement that triage is not representable there stands, and
  the keyed-resource shape is what makes "survives re-scan" true by construction rather than by a
  migration step.
- `SetTriage` is guarded by expected version and idempotent per request ID; a superseded record is
  retained and readable, never mutated.
- Dashboard reads accept filters for scanner class, severity, class, age range, lifecycle state and
  owning team, with signed, tenant-bound cursors. `GetFindingsSummary` returns counts and facet
  values computed **under the caller's authorization**; a facet value that exists only in a repository
  the caller may not read is absent, not zero.
- No triage request may carry a finding's severity, lifecycle, or an `allowed` flag as input.

Additive events under `contracts/events/security/v1`: `FindingTriaged`, carrying opaque identifiers,
tenant and repository scope, prior and new state, and actor. It never carries justification text,
source code, provenance bytes, or a policy outcome.

The policy follow-up adds this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `findings.triage` | `finding` | repository, scanner class, severity, current triage state |
| `findings.read` | `repository` | scanner class, severity, lifecycle state, owning team |
| `findings.summary.read` | `repository` | requested facet dimensions |

Severity, lifecycle, owning team and current triage state are facts produced by Security/Findings,
never claims arriving on gRPC, HTTP, or an event.

## Data owned

Security/Findings owns triage records, their versions and history, idempotency keys, and its event
payloads. Identity & Access owns team membership, which arrives as opaque identifiers or an event-fed
projection. Policy owns authorization; Audit owns immutable records.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A tenant-scoped principal sets a triage state at the current expected version, reads it
  back, and pages a filtered list; replaying a request ID is idempotent and a stale version changes
  no state.
- [ ] AC2: Ingesting a later scan for the same finding identity leaves the triage record attached and
  unchanged — no re-attachment step exists, because the record is keyed by identity.
- [ ] AC3: An authenticated principal cannot triage, read, summarize, page, or consume an event for
  another tenant; every failure is coarse and non-enumerating, including cursors, counts and facets.
- [ ] AC4: A count, facet or "more results" indicator never varies with findings in a repository the
  caller may not read, proven by differential tests against two principals.
- [ ] AC5: Every triage transition receives a PDP decision with server-derived context and appends
  exactly one immutable audit record correlated to the decision ID; a denial creates no triage record.
- [ ] AC6: A superseded triage record remains retrievable with its actor, timestamp and justification.
- [ ] AC7: The finding message carries no triage field, proven by a contract test; `buf lint` and
  `buf breaking` are green and the change is additive within v1 (ADR-0032, T-0020).
- [ ] AC8: Boundary tests prove no other context reads Security/Findings' tables for triage, and that
  the BFF performs no filtering, ranking, or authorization of its own.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | every request, cursor, count, facet and event is tenant-scoped |
| G2 least privilege | triage and reads are PDP decisions; counts and facets are authorization-derived |
| G4 change governance | additive-only within v1, gated in CI, so consumers extend rather than break |
| G5 auditability | transitions are immutable, decision-correlated, and history-preserving |
| G9 least-privilege footprint | events and boundaries carry opaque identifiers and facts, never justification text, source, or provenance bytes |

## Non-functional

- Triage writes are serializable per finding; reads stay within interactive latency at Phase-2 scale.
- Summary computation must not degrade into an unfiltered aggregate with a post-filter; the
  authorization filter is part of the query, not a mask.
- Denial and not-found errors do not distinguish nonexistent, cross-tenant and unauthorized findings.

## Open questions / assumptions

- **Justification requirement.** Whether `ACCEPT` and `FALSE_POSITIVE` require non-empty justification
  is an approval-time product decision; the contract carries the field either way.
- **Facet cardinality bounds** for `GetFindingsSummary` are unset; an org-wide facet over a large
  tenant may need a bound, which would be an additive field.
- **Assumption:** SPEC-0026's `DEFER`-expiry open question, if answered with an expiry, adds an
  additive optional field here rather than a new resource.
