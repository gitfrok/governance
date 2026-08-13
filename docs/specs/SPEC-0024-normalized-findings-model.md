# SPEC-0024: Normalized findings model & scanner ingestion

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Security/Findings (ADR-0022); Policy and Audit as provider/sink
- **ADRs:** 0015, 0006, 0007, 0022, 0025, 0032
- **Task(s):** T-0022; T-0023, T-0024, T-0025, T-0026 (consumers)
- **PRD:** PR-13

## Problem / context

Phase 2's wedge is that every scanner's output lands in one place, in one shape, where code is
reviewed (PRD §3). Five scanner classes — SAST, dependency, secrets, container, DAST — each report a
different native shape, on a different cadence, with a different notion of "the same problem seen
again". Without one normalized model and one **identity rule**, a re-scan produces a new set of
findings, so triage state cannot survive it (PR-14), a finding cannot be attributed to the change
that introduced it (PR-15), and an evidence pack has no stable scan-gate record to cite (PR-17).

Identity is the hard part and it is a *governance* concern, not a formatting one: a finding whose
identity moves when an unrelated line moves silently resets a compliance owner's accepted-risk
decision. This spec fixes the model and the identity rule before any of the four consumers exist.

## In scope

- One normalized finding shape covering all five scanner classes, owned by Security/Findings.
- A **deterministic identity rule** — what identity is a function of, and what it must be invariant
  to — stated as invariants, not as a hash construction.
- Ingestion of scanner output through one boundary: scanners are adapters, not domain, and a
  scanner-native payload is carried as opaque provenance.
- Tenant scoping of every finding and every read of one (SPEC-0001).
- PDP authorization of ingestion, with audited denial (ADR-0006, ADR-0007).
- The proof obligation that identity stability is demonstrated against real scanner output on a real
  repository across at least two scans.

## Out of scope

- The dashboard read surface, filtering, and **triage state** — T-0023 extends this model additively
  (SPEC to follow); no triage field is defined here.
- Attribution of a finding to the merge request that introduced it — T-0024.
- Any policy that *gates* on a finding — T-0025 consumes findings; this spec grants no gating
  semantics and no severity thresholds.
- Evidence-pack sections — T-0026.
- **Which scanners ship.** Scanner selection is an implementation choice, not a PRD commitment
  (PRD §12.4). This spec fixes the boundary that keeps the choice reversible.
- Scan *execution and dispatch*. Scans run as CI jobs under SPEC-0010/SPEC-0020; this spec begins at
  the point where a completed scan has output to ingest.
- Deduplication *across* scanner classes into a single merged finding. Two scanners reporting the
  same defect remain two findings (see AC3); a merged view, if ever wanted, is a later decision.

## Contracts touched

Additive `contracts/proto/security/v1` and `contracts/events/security/v1`, specified in
**SPEC-0025** (findings ingestion contract). Additive-only within v1 and gated by `buf lint` +
`buf breaking` (ADR-0032, T-0020). This spec defines the behavior; SPEC-0025 defines the boundary.

## Data owned

Security/Findings owns findings, their identities, their scan records, and its event payloads. It
reads no other context's tables. Repository/Git facts it needs (repository identity, revision) arrive
as opaque identifiers on the ingestion boundary or through event-fed local projections, never by
reaching across (ADR-0022). Policy owns authorization; Audit owns immutable records.

## The identity rule

A finding's identity is a **deterministic function of a named input set**, computed server-side. It
is a function of: the tenant, the repository, the reporting **tool** (scanner class and tool
identity), the **rule** the tool reports, and a **location** whose components are content-derived —
the artifact the finding sits in and the enclosing content that carries it — plus, for a dependency
or container finding, the affected component and version rather than a file line.

Identity is **invariant to**: the commit, the scan run, the absolute line number, and any edit
elsewhere in the file that shifts the finding's location without changing the content it names.

Identity **distinguishes**: two different rules at one location; the same rule at two locations; and
the **same defect reported by two different tools** — those are two findings, not one, and neither is
dropped (AC3).

Implementations choose the hash construction. They may not choose the input set: adding or removing
an input changes every existing identity and is therefore a spec amendment, not a refactor.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A findings contract in `governance/contracts` covers all five scanner classes — SAST,
  dependency, secrets, container, DAST — in one normalized finding shape, additive-only within v1
  and green under `buf lint` and `buf breaking`.
- [ ] AC2: Identity is stable across scans. Re-scanning an unchanged defect at a later commit yields
  the same identity, and an unrelated edit that shifts the finding's line yields the same identity.
- [ ] AC3: Identity discriminates. Two tools reporting the same defect class at the same location
  produce two findings, neither silently dropped or collapsed; two different rules at one location
  and one rule at two locations are likewise distinct.
- [ ] AC4: Ingestion and reads are tenant-scoped. An authenticated principal cannot ingest into,
  read, or enumerate findings for another tenant, and every such failure is coarse and
  non-enumerating (SPEC-0001).
- [ ] AC5: Ingestion is authorized by the PDP with server-derived context; an unauthorized ingest is
  denied and the denial is recorded on the immutable denial path (ADR-0006, ADR-0007). No caller,
  BFF, or event payload can assert an authorization outcome.
- [ ] AC6: No scanner-specific field is representable in the normalized model. A scanner-native
  payload is carried as **opaque provenance** — retrievable, never interpreted by the domain, never
  promoted to first-class schema — and adding a scanner requires no model change.
- [ ] AC7: AC2 and AC3 are proven against **real scanner output on a real repository across at least
  two scans**, not against fixtures. A fixture-only proof does not satisfy this criterion.
- [ ] AC8: Ingesting the same scan result twice is idempotent per tenant, scan, and request ID: it
  creates no duplicate finding and no second audit record of the same event.
- [ ] AC9: A finding that a later scan no longer reports is **resolved, not deleted** — its identity
  and history remain retrievable, so a consumer can distinguish "fixed" from "never seen".
- [ ] AC10: Boundary tests prove Security/Findings imports no other context's internal packages and
  reads no other context's tables (ADR-0022, T-0002/T-0009 gates).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | every finding, ingest, read, and event is tenant-scoped; cross-tenant access is coarse and non-enumerating |
| G2 least privilege | ingestion is a PDP decision with server-derived context; no caller-asserted outcome |
| G3 supply chain | all five scanner classes normalize into one model, which is the wedge's foundation (ADR-0015) |
| G5 auditability | ingest and denial produce immutable records; a resolved finding keeps its history (AC9) |
| G6 compliance | stable identity is what lets an accepted risk and a scan gate still mean something at audit time |
| G9 least-privilege footprint | the boundary carries opaque identifiers and a normalized model, never scanner credentials or raw tool internals as schema |

## Non-functional

- Ingestion is asynchronous with respect to the scan job and must not degrade interactive git or web
  latency for the tenant beyond the PRD §9 targets; a large scan result is throttled ahead of
  degrading normal traffic.
- Identity computation is pure and reproducible: the same input set yields the same identity on any
  node, in any process, at any time.
- Scan volume is a fair-use dimension (PRD §6); ingestion records what a later metering surface will
  read, without implementing metering here.

## Open questions / assumptions

- **Location derivation for SAST and secrets** is content-derived by intent, but the exact enclosing
  unit (symbol, hunk, normalized snippet) is an implementation choice constrained by AC2 and AC3. If
  no construction satisfies both against real output, that is a spec amendment, not a test to relax.
- **The event catalog remains undocumented** (ADR-0022 follow-up, parked). These events add more
  protobuf full names to a catalog nothing describes; that debt is recorded, not resolved here.
- **Retention of findings** is unspecified. The audit retention policy is an open ADR-0007 follow-up
  (PRD §12.3) and it gates T-0026/T-0027, not this spec; a findings-specific retention rule, if
  needed, follows that decision rather than preceding it.
- **Assumption:** scan execution rides CI v0. In the dev cluster there is no gVisor RuntimeClass
  under rootless podman, so scan dispatch may be demonstrable only on T-0003's cluster lane
  (T-0017's recorded host limit). That constrains where AC7 can be executed, not what it requires.
