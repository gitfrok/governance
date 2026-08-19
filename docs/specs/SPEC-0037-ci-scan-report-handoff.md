# SPEC-0037: CI scan report handoff to the findings plane

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s); approved (2026-08-14)
- **Owner:** platform
- **Context(s):** CI/CD (writes the report), Security/Findings (consumes it) — ADR-0022
- **ADRs:** 0059 (decides the path), 0022, 0025, 0050, 0055 (retention, and why it does not apply here)
- **Task(s):** T-0029

## Problem / context

`CIJobFinished` has no subscriber, so a scan that runs inside a pipeline reaches the findings plane
only if something outside the plane calls `IngestScanResults` over gRPC. Phase 2 exited with this
recorded as unbuilt, and two acceptance criteria depend on it: **T-0024 AC4** and **T-0028 AC4**
measure findings and index freshness on a real pipeline, which cannot be observed on a path that does
not exist.

ADR-0059 decided the shape: the scan step persists its raw report, and a Security subscriber
correlates the job, normalizes the report, and ingests it in-process. This spec fixes the report
surface that decision needs — where a report lives, what bounds it, how long it stays — and the
subscriber's behaviour, including the cases where doing nothing is the correct answer.

SPEC-0020 states that "artifact persistence is deferred". This spec is the narrow, deliberate
exception to that deferral: **scan reports only**, not a general artifact product. Nothing here makes
build outputs, caches or logs persistable.

## In scope

- A tenant-scoped, size-bounded scan-report object written by the scan step and addressed by
  `(tenant, repository, job, attempt, scanner class)`.
- Retention and size limits for those objects, and what happens when either is exceeded.
- A Security subscriber to `CIJobFinished` that correlates, fetches, normalizes and ingests.
- The ingest's principal, idempotency key, and audit shape.
- The no-report, failed-job, oversized-report and unparseable-report cases.

## Out of scope

- General CI artifact persistence, caches, or build outputs — SPEC-0020's deferral stands for
  everything except a scan report.
- Scan *dispatch*: which pipelines run which scanners, and the gVisor RuntimeClass they need
  (SPEC-0010, SPEC-0020, T-0003's cluster lane).
- The normalized findings model itself and the identity rule (SPEC-0024), and the ingest contract
  (SPEC-0025). This spec adds a producer, not a second ingest path.
- Enriching `CIJobFinished`. Correlation uses the existing `ci/api.Jobs.Get`; no contract changes.

## Contracts touched

**none.** No proto and no event changes: the subscriber reads `ci/api.Jobs.Get` in-process and calls
the existing `IngestScanResults` application port. If a later measurement shows the per-event job
read is too costly, enriching the event is an additive change under its own governance PR.

## Data owned

The scan report object is **CI/CD's** data, written by the runner and read by Security through a
composed port — the same seam every other cross-context read uses (ADR-0022). Security owns the
findings derived from it. The object store is tenant-scoped; a report key carries its tenant, and a
read outside that tenant is refused as coarsely as a missing one (SPEC-0001).

## Acceptance criteria (each becomes a test)

- [ ] AC1: A completed scan step's report is durable: after the attempt's pod is gone, the report is
  readable by key `(tenant, repository, job, attempt, scanner class)`, and by nothing else. A read
  naming another tenant returns the same coarse not-found as a key that was never written.
- [ ] AC2: `CIJobFinished` drives the ingest. A published event whose job has a report produces
  exactly one ingested scan per scanner class, with the revision taken from the job's `CommitSHA` —
  never from the report, the event, or any caller-supplied field.
- [ ] AC3: The ingest runs as the job's triggering principal (`ActorID`/`ActorRoles` from the `Job`),
  and the PDP decides it like any other ingest. A report that names an actor, tenant, repository or
  role is ignored on all four; nothing in the report can widen what the ingest may do (ADR-0059
  decision 1, invariant 2).
- [ ] AC4: A job with no report is a no-op: no scan is created, no finding is opened, and — critically
  — **no finding is resolved**. A pipeline with no scan step must not clear a repository's findings
  (SPEC-0024 lifecycle).
- [ ] AC5: A failed or cancelled job whose report exists is ingested exactly like a successful one.
  The terminal state is recorded on the scan, never used to filter it (ADR-0059 decision 2).
- [ ] AC6: Delivery is idempotent. Re-publishing `CIJobFinished` for the same `(job, attempt)`, or
  redelivering it after a restart, ingests once: the request ID is derived deterministically from
  `(JobID, AttemptID, scanner class)` and replays through the existing scan-chunk idempotency. The
  derived ID never enters a reserved request-ID namespace, and any prefix this introduces is refused
  from callers at the ingest boundary exactly as `audit:` is (review N2).
- [ ] AC7: A report larger than the configured limit is refused at write time with the job's outcome
  saying so; it is never truncated into a partial report, because a partial scan report silently
  becomes "these findings are all there were" and resolves the rest.
- [ ] AC8: An unparseable or unrecognized report fails the ingest loudly — an audit record and a
  failure the operator can see — and changes no finding. Ambiguity never resolves findings.
- [ ] AC9: Reports are retained for a bounded, configured period and are then deleted. Deletion
  removes no finding, no scan record and no audit record: the derived evidence outlives its source,
  and a pack assembled after deletion is unaffected. ADR-0055's never-delete rule governs the audit
  chain, not reports, and this AC is where the difference is asserted.
- [ ] AC10: The end-to-end path is proven on the composition: a pipeline finishing produces findings
  visible on the dashboard and on the merge request, with the freshness interval measured — the
  measurement T-0024 AC4 and T-0028 AC4 have been waiting for.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | report keys, reads, and the derived ingest are tenant-scoped; cross-tenant reads are coarse not-found (AC1) |
| G2 authorization | the ingest is PDP-decided under a server-derived principal; the report asserts nothing (AC3) |
| G3 auditability | every ingest keeps SPEC-0025's exactly-one audit record; failures are audited too (AC8) |
| G4 evidence | the durable report makes a finding re-derivable; deleting it never edits derived evidence (AC9) |
| G5 boundaries | no contract change, no cross-context import — CI writes, Security reads through a composed port |
| G6 idempotency | deterministic request ID over `(job, attempt, class)` through existing replay machinery (AC6) |
| G7 fail-safe | no report, oversized, or unparseable never resolves findings (AC4, AC7, AC8) |
| G8 footprint | one object per scan per attempt, size- and age-bounded; no general artifact product |
| G9 operability | freshness is measurable end to end (AC10); refusals surface in the job outcome |

## Non-functional

- Report size limit and retention period are per-environment configuration (invariant 13), not
  compiled in. Defaults are stated in the task and reflected in the runbook.
- The subscriber must not block the dispatcher: ingest runs off the event, and a slow or failing
  ingest delays findings, never job completion.

## Open questions / assumptions

- **Metering.** Nothing measures report-store growth. ADR-0059 carries this as an open follow-up;
  the PRD §6 fair-use dimensions may need one for scan-report bytes.
- **Multiple scanner classes per attempt.** Assumed: one report object per class, so a job running
  Semgrep and gitleaks produces two ingests and the multi-class attribution path (review H5) sees
  both. A single combined report would work too, and the choice is the task's to fix in the key
  shape — but it must be one of the two, consistently, because the identity rule discriminates by
  tool.
- **Delivery guarantee.** The in-process bus is at-most-once on restart. AC6 makes redelivery safe;
  it does not make delivery guaranteed. If a plane restarts between the event and the ingest, the
  findings are missing until the next scan — acceptable while the report is durable and re-ingestible,
  and the recovery path (a backfill over reports without a scan record) is left to the task to state.
