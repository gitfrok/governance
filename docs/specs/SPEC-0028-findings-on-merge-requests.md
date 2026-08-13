# SPEC-0028: Findings on merge requests

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Security/Findings, Code Review, CI/CD, Policy, Audit
- **ADRs:** 0015, 0005, 0012, 0006, 0007, 0022, 0032
- **Task(s):** T-0024; T-0025, T-0026 (consumers)
- **PRD:** PR-15

## Problem / context

A finding a reviewer never sees changes nothing. PR-15 puts findings in the merge request that
**introduced** them, in the same place code is reviewed (ADR-0015). "Introduced" is the load-bearing
word: attributing every finding a scan happens to report during an MR's lifetime would blame a merge
request for pre-existing debt, and a security lead who cannot trust the attribution will not gate on
it (SPEC-0029).

This spec fixes the attribution rule with the same status the identity rule has in SPEC-0024 — an
invariant, not an implementation choice.

## In scope

- The attribution rule for "introduced by this merge request".
- Presentation of an attributed finding inline at its location in the MR diff, including its triage
  state from SPEC-0026.
- Freshness: results visible within one pipeline duration (PRD §9).
- Honest rendering of a scan that failed, timed out, or has not run.
- Re-attribution when the MR's head or merge base moves.

## Out of scope

- Gating a merge on a finding (SPEC-0029/0030). This spec makes findings visible; it grants no
  blocking semantics.
- The findings model and identity (SPEC-0024), ingestion (SPEC-0025), the dashboard and triage
  resource (SPEC-0026/0027).
- Scan dispatch and job lifecycle (SPEC-0010, SPEC-0020) — a scan on an MR is a CI job.
- Review threads and line comments, which remain deferred from SPEC-0019.

## The attribution rule

A finding is **introduced by a merge request** when it is present at the merge request's current head
revision and **absent at the merge base** of its target branch. Attribution is a set difference
between two scan results at two revisions, compared by SPEC-0024 finding identity.

It is **not** "first seen during the MR's lifetime": a scheduled scan of the target branch landing
mid-review must not become this MR's finding, and a finding that already existed on the target must
not appear as introduced.

When the head moves, attribution is recomputed against the new head. When the **merge base** moves —
a retarget, a rebase, or the target branch advancing — attribution is recomputed against the new
base, and a finding that ceases to satisfy the rule ceases to be attributed. Attribution is therefore
derived state, never a stored claim that outlives its inputs.

If either side of the comparison is missing — the base has never been scanned, or the head scan
failed — the merge request reports **attribution unavailable**, and never an empty finding set.

## Data owned

Security/Findings owns findings, identity, triage, and the derived attribution. Code Review owns the
merge request, its head revision and its target ref; those reach Security/Findings as opaque
identifiers or an event-fed projection. CI/CD owns the scan job. No context reads another's tables
(ADR-0022).

## Contracts touched

Additive only, no new boundary:

- `contracts/proto/security/v1` gains a read operation for findings attributed to an opaque merge
  request ID, with the same required context, tenant scoping and signed cursors as SPEC-0025/0027,
  returning each finding with its triage state, its location in the head revision, and an attribution
  status (`ATTRIBUTED`, `PRE_EXISTING`, `UNAVAILABLE`).
- `contracts/events/security/v1` gains `FindingsAttributed`, carrying opaque merge-request,
  repository and tenant identifiers, the head and base revisions compared, and counts by severity —
  never source, provenance bytes, or a policy outcome.
- Security/Findings consumes Code Review's existing merge-request events into a tenant-scoped local
  projection to learn head and target changes; it does not call Code Review on a read path.

Both are additive within v1 and gated by `buf lint` + `buf breaking` (ADR-0032, T-0020). The policy
follow-up adds `findings.read` on resource type `merge_request`, with server-derived context carrying
repository, head revision and attribution status.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A finding present at the MR head and absent at the merge base is attributed to the MR; a
  finding present at both is `PRE_EXISTING` and is not attributed.
- [ ] AC2: A scan of the target branch that lands during the MR's lifetime does not, by itself, cause
  attribution — the rule is the base/head difference, not first-seen time.
- [ ] AC3: Moving the head, retargeting, or rebasing recomputes attribution against the new pair; a
  finding that no longer satisfies the rule is no longer attributed.
- [ ] AC4: An attributed finding renders inline at its location in the MR diff and remains reachable
  when a later push within the MR shifts its line (SPEC-0024 AC2 identity stability).
- [ ] AC5: A finding triaged `ACCEPT` or `FALSE_POSITIVE` renders in that state, not as new.
- [ ] AC6: Scan results are visible on the merge request **within one pipeline duration**, measured
  against a real pipeline rather than asserted (PRD §9).
- [ ] AC7: A failed, timed-out, missing or not-yet-run scan renders as `UNAVAILABLE` with the reason;
  it never renders as "no findings".
- [ ] AC8: The surface is tenant-scoped and permission-filtered; a caller without read on the merge
  request or its repository sees nothing, coarsely.
- [ ] AC9: The BFF aggregates only — no attribution, filtering or authorization logic (invariant 18)
  — proven by a boundary test; Security/Findings reads no Code Review table.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | attribution, reads and projections are tenant-scoped |
| G2 least privilege | MR findings reads are PDP decisions; no caller-asserted attribution |
| G3 supply chain | findings reach the reviewer at the moment of change, which is the wedge (ADR-0015) |
| G4 change governance | a trustworthy attribution rule is the precondition for gating on it (SPEC-0029) |
| G5 auditability | attribution is derived and reproducible from two named revisions, so a later evidence claim can be re-derived |

## Non-functional

- Attribution is recomputed asynchronously on head, base or scan change, and must converge within the
  freshness bound; a stale attribution is reported as stale rather than served as current.
- Recomputation is idempotent per merge request, head and base triple.
- A large diff or a large finding set is bounded and paginated; the MR page never blocks on a full
  org-scale query.

## Open questions / assumptions

- **Scan cost on every head push.** Whether every push in an MR triggers a full re-scan or an
  incremental one is an implementation choice constrained by AC6, but it has a fair-use consequence
  (scan volume, PRD §6). If a bound is needed, it is a policy decision, not a silent cap.
- **Assumption:** scan execution rides CI v0 (SPEC-0010/0020). The dev cluster has no gVisor
  RuntimeClass under rootless podman, so demonstrating AC6 may require T-0003's cluster lane —
  T-0017's recorded host limit, which constrains where the criterion is proven, not what it requires.
- **Assumption:** the merge base is computable from Repository/Git for the MR's source and target
  refs. If a target with no common ancestor is representable, it reports `UNAVAILABLE` rather than
  attributing everything.
