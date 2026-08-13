# SPEC-0030: Policy decision-provenance and dry-run contract

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Policy (PDP), Code Review, Security/Findings, Audit
- **ADRs:** 0006, 0007, 0022, 0032
- **Task(s):** T-0025; T-0026 (consumer)
- **PRD:** PR-16

## Problem / context

SPEC-0029 requires a deciding policy version on every decision, a dry-run mode, and findings as a
merge-gate input, and leaves the boundary unspecified. SPEC-0002 defined the PDP surface for Phase 0
without decision provenance. Without a contract, the version would be reconstructed from logs, a
dry-run result would be indistinguishable from an enforced one downstream, and a caller could supply
its own findings facts to a gate. This specification defines the additive boundary before
implementation.

## In scope

- Additive decision-provenance fields on the PDP decision surface: bundle revision, input digest,
  decision ID, and evaluation mode.
- An explicit **dry-run evaluation** operation over a candidate bundle and a historical range.
- Server-derived findings context on merge decisions.
- The reviewed action vocabulary this adds.

## Out of scope

- A policy authoring or storage surface (SPEC-0029 reading B — requires an ADR first).
- Findings ingestion, triage and attribution surfaces (SPEC-0025, SPEC-0027, SPEC-0028).
- Evidence-pack assembly (SPEC-0032), which reads decision records through its own surface.
- Redefining any existing SPEC-0002 or SPEC-0019 action.

## Contracts touched

Additive on `contracts/proto/policy/v1`:

- The decision response gains `bundle_revision`, `input_digest`, `decision_id` and `mode`
  (`ENFORCED` or `DRY_RUN`). These are **server-produced**; a request that carries them is rejected
  rather than ignored, and no caller, BFF, adapter or event may assert an `allowed` outcome.
- `EvaluateDryRun` accepts a candidate bundle reference and a bounded historical range or explicit
  input set, and returns per-input would-be decisions with the same provenance fields and
  `mode = DRY_RUN`. It writes no enforcement, changes no state, and its results are never consumed as
  an authorization outcome.
- Merge-gate decision input gains server-derived findings facts: attributed finding counts by
  severity, the highest attributed severity, and the triage records relied upon — each produced by
  Security/Findings under SPEC-0028, never claimed by a caller.
- A decision record is retrievable by `decision_id` with its mode, bundle revision, input digest,
  actor, resource, action, outcome and timestamp. Rule source text is not exposed on this surface.

Audit records under `contracts/events/audit/v1` gain the same provenance fields additively; a
`DRY_RUN` decision is never written as an enforced control record and is labelled wherever it appears.

The policy follow-up adds this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `merge_request.merge` | `merge_request` | existing SPEC-0019 context **plus** attributed findings by severity and relied-upon triage records |
| `policy.dryrun` | `tenant` | candidate bundle reference, range bounds |
| `policy.decision.read` | `decision` | tenant, resource, mode |

Findings counts, severities and triage states are facts produced by Security/Findings; bundle
revision and mode are facts produced by Policy. None is representable as a caller claim.

## Data owned

Policy owns bundles, revisions, decision records and dry-run results. Security/Findings owns the
findings facts; Code Review owns merge-request state; Audit owns immutable records. Policy reads no
other context's tables — facts arrive as server-derived context assembled by the calling context's
own state, and a fact that cannot be assembled fails closed (SPEC-0029 AC9).

## Acceptance criteria (each becomes a test)

- [ ] AC1: Every decision response and every audit record carries bundle revision, input digest,
  decision ID and mode; a decision is retrievable by decision ID afterwards with all four.
- [ ] AC2: A request that supplies bundle revision, input digest, decision ID, mode, or an `allowed`
  flag is rejected, not silently ignored.
- [ ] AC3: `EvaluateDryRun` over a historical range returns would-be decisions, writes no enforcement,
  mutates no state, and every produced record is labelled `DRY_RUN` in the audit chain and anywhere a
  consumer reads it.
- [ ] AC4: A merge decision receives findings facts derived from SPEC-0028 attribution; a caller
  cannot substitute them, and a missing or stale fact fails closed for a rule that requires it.
- [ ] AC5: A bundle-revision change invalidates cached decisions by construction; a decision made
  under revision *n* is never served after revision *n+1* is active (SPEC-0002).
- [ ] AC6: Every operation is tenant-scoped; a cross-tenant decision read, dry-run, or event
  consumption is a coarse denial that does not distinguish nonexistent from unauthorized.
- [ ] AC7: `buf lint` and `buf breaking` are green; all additions are additive within v1 and
  generated-code freshness is green at the composition boundary (ADR-0032, T-0020).
- [ ] AC8: Boundary tests prove Policy reads no other context's tables and that no BFF or adapter
  computes, caches, or overrides a decision.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G2 least privilege | outcomes and provenance are server-produced; nothing is caller-assertable |
| G4 change governance | dry-run makes a rule's effect knowable before it binds, and the deciding revision is recorded |
| G5 auditability | every decision is immutable, provenance-carrying, and retrievable by ID |
| G6 compliance | evidence can cite the exact policy version and input digest behind a control |
| G9 least-privilege footprint | the surface exposes decisions and facts, never rule source, findings payloads, or credentials |

## Non-functional

- Provenance adds no more than negligible latency to the enforced decision path.
- Dry-run is batchable, bounded per request, and isolated from the enforced path's resources.
- Denial and not-found errors do not distinguish nonexistent, cross-tenant and unauthorized decisions.

## Open questions / assumptions

- **Input-digest construction** must be stable and reproducible so an auditor can re-derive it; the
  exact canonicalization is an implementation choice constrained by AC1, but a change to what the
  digest covers is a spec amendment.
- **Dry-run range bounds** are unset; a large historical range needs a cap, which is an additive
  field rather than a silent truncation.
- **Settled 2026-08-14:** SPEC-0029 **reading A** is approved — a candidate bundle reference
  identifies reviewed code in `governance/`, not a tenant-authored record. Reading B would change
  this surface materially and requires an ADR first.
