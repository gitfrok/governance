# SPEC-0029: Security & approval policy — versioned, dry-run, enforced at merge

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Policy (PDP), Code Review, Security/Findings, Audit
- **ADRs:** 0006, 0007, 0029, 0015, 0022
- **Task(s):** T-0025; T-0026 (consumer)
- **PRD:** PR-16

## Problem / context

Phase 1 enforces branch protection and required approvals through the PDP (SPEC-0009, SPEC-0019).
Phase 2 adds two things that make policy a *governance* surface rather than a deployment detail: the
**version that decided** must be recorded on every decision, and a policy must be **dry-runnable**
before it enforces. Without the first, an evidence pack can state that a merge was gated but not by
what (PR-17). Without the second, the only way to learn what a rule does is to enforce it on real
merges.

Security findings become a policy input here: a rule may block a merge on the findings SPEC-0028
attributes to it.

## Design fork — **settled at approval (2026-08-14): reading A**

PR-16's persona is a tenant security lead, but Phase 1's policy source is Rego in
`governance/policies`, reviewed via PR (SPEC-0009 AC2). Two readings satisfy the requirement:

- **A. Governance-PR authoring.** Policy stays reviewed code; git is the version store; the recorded
  policy version is the bundle revision (SPEC-0002). Dry-run runs the candidate bundle against real
  history. No new mutable policy source, no new authoring surface.
- **B. In-product per-tenant authoring.** A security lead authors and versions policy in the product;
  the platform becomes a second policy source with its own review, promotion and blast radius.

**Reading A is the approved reading (2026-08-14).** It adds no new trust boundary and every
Phase-0/1 invariant already covers it; the acceptance criteria below are written against it. Reading
B is a materially larger contract surface and, per ADR-0001, a **new decision — a Proposed ADR, not a
spec choice**. Should a tenant later require in-product authoring, that ADR precedes any contract
work and supersedes this section. **That ADR is now written: ADR-0082 (Accepted) keeps reading B
deferred** — the reopen trigger is a named tenant need, not the PRD row — with check 14 holding the
absence at the wire; reading A remains the approved reading.

## In scope

- Policy **versioning**: every decision records the deciding version, retrievable later.
- **Dry-run**: evaluating a candidate policy against real history without enforcing, with dry-run
  decisions distinguishable from enforced ones.
- **Findings as a policy input** for a merge decision, sourced from SPEC-0028 attribution.
- Composition with SPEC-0019's protected-branch and approval enforcement.
- Immutable audit of enforced decisions, carrying actor, input digest, outcome and policy version.

## Out of scope

- An authoring UI, tenant-scoped policy storage, and policy promotion workflow — reading B above.
- Findings ingestion, triage, and attribution (SPEC-0024…0028).
- Evidence-pack assembly (SPEC-0031/0032), which reads what this spec records.
- Auditor access (SPEC-0033).
- Changing what the PDP is: OPA remains the decision point (ADR-0006); this adds inputs and
  provenance, not a second evaluator.

## Contracts touched

Additive policy surface, specified in **SPEC-0030**. New Rego rules live in `governance/policies`;
the merge decision's server-derived context gains findings facts. No existing action is redefined.

## Data owned

Policy owns rules, bundle revisions, decision records and their versions. Security/Findings owns the
findings facts a decision reads; Code Review owns merge-request state; Audit owns immutable records.
Policy depends on no context (ADR-0022 provider/sink rule): findings and approval facts arrive as
server-derived context on the decision request, not as a table read.

## Acceptance criteria (each becomes a test)

- [ ] AC1: Every decision records the **policy version** that decided it — the bundle revision under
  reading A — and that version is retrievable from the decision record afterwards.
- [ ] AC2: A candidate policy can be **dry-run** against real history: it reports what it would have
  decided, enforces nothing, and its records are distinguishable from enforced decisions everywhere
  they appear, including audit and any later evidence section.
- [ ] AC3: A security rule blocks a merge on an attributed finding that violates it (for example a
  severity threshold), and the block is a PDP decision with server-derived findings context — never
  UI logic, a caller assertion, or a BFF check.
- [ ] AC4: A finding triaged `ACCEPT` or `FALSE_POSITIVE` (SPEC-0026) does not block, and the
  decision records which triage record it relied on.
- [ ] AC5: Security rules **compose with** SPEC-0019's protected-branch and approval enforcement;
  neither replaces the other, and both are enforced server-side.
- [ ] AC6: An **imported approval never satisfies** a policy requirement — only first-party approvals
  gate a merge (ADR-0029 §4), proven by a merge attempt whose only approval is imported.
- [ ] AC7: A policy change invalidates every cached decision by construction: invalidation is by
  **bundle revision**, not by clock (SPEC-0002's answered open question).
- [ ] AC8: Every enforced decision appends exactly one immutable audit record carrying tenant, actor,
  resource, action, outcome, request ID, decision ID, **input digest** and policy version (ADR-0007).
- [ ] AC9: A missing, stale or malformed findings input **fails closed** for a rule that requires it;
  it must not be replaced by a fail-open default or a synchronous cross-context table read.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G2 least privilege | every gate is a PDP decision with server-derived context |
| G3 supply chain | findings become an enforceable merge condition, not an advisory panel |
| G4 change governance | rules are reviewed, versioned, and dry-runnable before they bind |
| G5 auditability | decisions are immutable and carry the deciding version and input digest |
| G6 compliance | a later evidence pack can state not only that a merge was gated, but by which policy version |

## Non-functional

- A merge-gate decision stays within interactive latency, including the findings input.
- Dry-run over history is batchable and must not contend with enforced decisions on the hot path.
- Decision records are retained at least as long as the evidence range that may cite them — bounded
  by the retention decision below.

## Open questions / assumptions

- ~~**The authoring fork above.**~~ **Settled 2026-08-14: reading A** — governance-PR authoring,
  bundle revision as the recorded policy version. Reading B would require a Proposed ADR (ADR-0001)
  before any contract work — **ADR-0082 (Accepted) is that ADR** and keeps reading B deferred.
- **Retention of decision records** is unspecified here and gates SPEC-0031/0032: the audit retention
  policy is an open ADR-0007 follow-up (PRD §12.3). A Proposed ADR settles it; this spec stops.
- **SPEC-0002's AC4 fitness function is a tripwire, not a proof** — authorization logic has no import
  signature, so a green fitness run is not evidence that a gate is enforced. Prove AC3 and AC5 with
  behavioral tests.
- **Assumption:** severity thresholds and rule vocabulary are authored per tenant *in reviewed
  policy*, so a tenant-specific rule is a governance PR under reading A.
