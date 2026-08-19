# SPEC-0025: Findings ingestion and read contract

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Security/Findings, Repository/Git, CI/CD, Policy, Audit
- **ADRs:** 0015, 0006, 0007, 0022, 0032
- **Task(s):** T-0022; T-0023, T-0024, T-0025, T-0026 (consumers)
- **PRD:** PR-13

## Problem / context

SPEC-0024 fixes the normalized model and the identity rule, and deliberately leaves the shared
boundary unspecified. Without a contract, a scanner adapter would write Security/Findings' storage
directly, Code Review would read its tables to place a finding on a merge request, or the BFF would
decide what a caller may see. This specification defines the additive boundary before implementation,
so the four Phase-2 consumers (T-0023…T-0026) extend it rather than reinvent it.

## In scope

- An additive internal Security/Findings gRPC surface for ingesting a completed scan's results and
  for reading findings within a tenant.
- Required, server-verified request context on every operation; server-owned idempotency per scan and
  request ID.
- A normalized finding message covering all five scanner classes, with the scanner-native payload
  carried as **opaque provenance bytes** and a declared media type — never as interpreted fields.
- Additive Security/Findings events consumed by later Phase-2 contexts.
- The PDP action vocabulary for ingest and read.

## Out of scope

- Triage state and its transitions (T-0023), MR attribution (T-0024), gating semantics (T-0025), and
  evidence-pack sections (T-0026). Each extends this surface additively.
- Scan *dispatch* and job lifecycle — SPEC-0010/SPEC-0020 own those; this contract begins at a
  completed scan.
- Browser routes. The BFF aggregates this surface and shapes responses; it holds no domain logic
  (ADR-0020, invariant 18).
- Any authorization outcome supplied by a caller, a BFF, an adapter, or an event payload. The PDP
  alone answers allow or deny.

## Contracts touched

Additive `contracts/proto/security/v1/findings.proto` contains a `FindingsService` with these
internal operations:

- `IngestScanResults`, `GetFinding`, and `ListFindings`.
- Every request carries required context: tenant ID, verified actor ID, verified actor roles, and
  request ID. Actor and roles come from authenticated identity; a caller cannot assert them. Empty or
  cross-tenant context is a coarse denial that does not distinguish nonexistent from unauthorized.
- `IngestScanResults` accepts an opaque repository ID, an opaque revision, a scan descriptor (scanner
  class, tool identity, tool version, scan start/end), and a bounded, chunkable batch of normalized
  raw findings. It does **not** accept a finding identity: identity is computed server-side per
  SPEC-0024, so no adapter can assert or forge one.
- A normalized finding carries an opaque server-assigned identity, tenant and repository scope, the
  reporting tool and rule, severity, class, a content-derived location, first-seen and last-seen scan
  references, lifecycle state (`OPEN` or `RESOLVED`), and an opaque provenance blob with its media
  type. No filesystem path outside the repository, credential, scanner API token, policy outcome,
  triage state, or audit sequence is representable in v1.
- `ListFindings` is tenant-scoped and cursor-paginated with signed, tenant- and revision-bound
  cursors; a forged or cross-tenant cursor yields no content. Filters in v1 are repository, scanner
  class, severity, and lifecycle state. Filter facets and counts obey the same authorization as the
  result list — a count may not reveal a finding the caller may not read.

The contract also defines additive events under `contracts/events/security/v1`:
`ScanIngested`, `FindingOpened`, and `FindingResolved`. Events carry opaque identifiers, tenant and
repository scope, tool and rule identity, and severity. They never carry provenance bytes, scanner
credentials, source code, or a policy allow flag. A consumer builds its own tenant-scoped local
projection from them and does not call back into Security/Findings on a hot path (ADR-0022).

The policy follow-up adds this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `findings.ingest` | `repository` | scanner class, tool identity, revision |
| `findings.read` | `repository` | scanner class, severity, lifecycle state |
| `findings.read` | `finding` | repository, scanner class, severity |

Scanner class, severity, and lifecycle values are facts produced by Security/Findings from ingested
and server-computed state, never claims arriving on gRPC, HTTP, or an event.

## Data owned

Security/Findings owns findings, identities, scan records, provenance blobs, idempotency keys, and
its event payloads. CI/CD owns the scan job that produced the output; Repository/Git owns the
repository and revision the finding names. Policy owns authorization and Audit owns immutable
records. No context reads another context's tables; cross-context facts arrive as opaque identifiers
or through event-fed projections.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A tenant-scoped principal can ingest a completed scan's results, read a single finding,
  and page a filtered list; replaying a request ID is idempotent and creates no duplicate finding,
  event, or audit record.
- [ ] AC2: An authenticated principal cannot ingest into, read, list, or consume an event for another
  tenant; every such failure is coarse and non-enumerating, including cursors and counts.
- [ ] AC3: A caller cannot supply a finding identity, a lifecycle state, or a `first_seen` value.
  Identity and lifecycle are server-computed; a request that carries them is rejected rather than
  silently ignored.
- [ ] AC4: Every authorization-sensitive operation receives a PDP decision with server-derived
  context. No API, BFF, adapter, or event can carry an `allowed` assertion or a severity claim used
  as an authorization input.
- [ ] AC5: An accepted ingest appends exactly one immutable audit record with tenant, actor,
  repository resource, action, outcome, request ID, and decision ID; a PDP denial uses the existing
  immutable denial record and creates no finding.
- [ ] AC6: The provenance blob round-trips byte-for-byte with its media type and is never parsed by
  the domain; a malformed or oversized blob is rejected at the boundary without partial ingest.
- [ ] AC7: Contract and boundary tests prove no other context imports Security/Findings' internals or
  reads its tables, and that Security/Findings obtains repository and scan facts only from opaque
  identifiers or its own projections.
- [ ] AC8: The proto and event schemas pass `buf lint` and `buf breaking` against the published
  baseline, and generated-code freshness is green at the composition boundary (ADR-0032, T-0020).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | every request, cursor, count, event, and projection is tenant-scoped |
| G2 least privilege | ingest and read are PDP decisions; identity and lifecycle cannot be asserted by a caller |
| G3 supply chain | one boundary normalizes five scanner classes, keeping scanner choice reversible |
| G4 change governance | the contract is additive-only within v1 and gated in CI, so consumers evolve without breaking |
| G5 auditability | ingest and denial produce immutable, decision-correlated evidence |
| G9 least-privilege footprint | the boundary exposes opaque identifiers, a normalized model, and an opaque blob — never credentials, source, or storage detail |

## Non-functional

- Ingest is serializable per scan and idempotent per tenant, scan, and request ID; a partially
  delivered batch leaves no half-ingested scan visible to a reader.
- List reads stay within interactive latency at Phase-2 scale; cursors are bounded and signed, and a
  large result set never streams unbounded memory.
- Caller-visible denial and not-found errors do not distinguish nonexistent, cross-tenant, and
  unauthorized findings or repositories.

## Open questions / assumptions

- ~~**Proto package name.**~~ **Settled at approval (2026-08-14):** the package path is
  `contracts/proto/security/v1`, matching ADR-0022's bounded-context name "Security/Findings"; events
  are `contracts/events/security/v1`. SPEC-0035 keeps `search/v1` and SPEC-0032 keeps `audit/v1`.
- **Severity scale.** v1 assumes one normalized severity scale across scanner classes, with the
  tool's native severity preserved in provenance. If a mapping proves lossy in a way a policy author
  can observe (T-0025), the scale is a spec amendment.
- **Assumption:** consumers T-0023…T-0026 extend this surface additively rather than forking it —
  the same relationship SPEC-0019 has with T-0018. Any consumer needing a breaking change raises it
  as a governance PR first (ADR-0027).
