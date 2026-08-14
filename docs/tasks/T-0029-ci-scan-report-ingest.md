# T-0029: CI scan report → findings ingest (`CIJobFinished` wiring)

- **Status:** Done (2026-08-14) — backend@49d6bfa; AC1–AC9 proven locally with tests, AC10 recorded as a cluster-lane deferral against T-0003
- **Phase / Epic:** 2 carry-over / EP-11 (findings plane), closing the path EP-7 and EP-11 never joined
- **Repo(s):** governance (SPEC-0020 amendment, if the deferral note needs restating), then backend
  — ADR-0027 order, one commit per repo
- **Spec:** docs/specs/SPEC-0037-ci-scan-report-handoff.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0059, 0022, 0025, 0050
- **Owner:** unassigned

## Goal

Join CI to the findings plane on the path every record already describes: a scan step's report is
persisted, `CIJobFinished` drives a Security subscriber, and the findings land under the job's own
principal. This is the wiring T-0024 AC4 and T-0028 AC4 have been blocked on — freshness cannot be
measured on a path that does not exist — and the first item in T-0003's cluster-lane carried set.

## Acceptance criteria (test-first)

SPEC-0037 AC1–AC10 are the criteria; each becomes a test. Restated here only where the task adds a
delivery detail:

- [x] AC1: report objects are durable, tenant-scoped, and addressed by
      `(tenant, repository, job, attempt, scanner class)` — one object per scanner class per attempt.
- [x] AC2: the subscriber ingests off `CIJobFinished`, taking the revision from `Jobs.Get`'s
      `CommitSHA`, never from the report or the event.
- [x] AC3: the ingest runs as the job's triggering principal and is PDP-decided; the report asserts
      no identity.
- [x] AC4: a job with no report changes nothing — and resolves nothing.
- [x] AC5: a failed or cancelled job's report ingests like any other.
- [x] AC6: redelivery ingests once, via a request ID derived from `(JobID, AttemptID, class)`; the
      derived prefix is refused from wire callers exactly as `audit:` is.
- [x] AC7: an oversized report is refused at write time, never truncated.
- [x] AC8: an unparseable report fails loudly, audited, and changes no finding.
- [x] AC9: retention deletes reports without touching derived findings, scans or audit records.
- [ ] AC10: end-to-end on the composition — pipeline finishes, findings appear on the dashboard and
      the merge request, freshness measured. *(cluster-lane deferral — see exit record)*

## Tests to write first

- **unit:** subscriber correlation (revision from the job, not the event); the no-report no-op
  asserting **zero resolutions**; failed-state ingest; oversized and unparseable refusals.
- **contract:** the derived request ID's shape and its reserved-prefix refusal at the ingest
  boundary, alongside the existing `audit:` cases.
- **integration:** report written by a runner-shaped writer, read back after the attempt is gone,
  ingested, and visible through `ListFindings`; redelivery of the same event ingesting once.
- **boundary:** no cross-context import — Security must not import CI internals, and the job read
  goes through the composed port (`internal/arch` gates this).
- **policy-isolation:** an ingest derived from another tenant's job is refused; a report key outside
  the tenant is coarse not-found.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony: this touches authorization, tenant scoping
and audit.

## Notes / open questions

**Sequencing.** The report writer is useless without a scan step to write one, and scan *dispatch*
needs the gVisor RuntimeClass the dev host lacks (T-0017's recorded limit, owned by T-0003's cluster
lane). The wiring is still buildable and testable here: the tests drive the writer directly, and
AC10 is the only criterion that needs the cluster. Split the exit record accordingly rather than
letting AC10 hold the rest.

**Scanner-class fan-out.** SPEC-0037 assumes one report object per scanner class so the multi-class
attribution path (review H5) sees every tool at a revision. Fix that in the key shape before writing
the subscriber; a combined report would push class-splitting into the parser.

**Backfill.** The in-process bus is at-most-once across a restart. Reports are durable, so a
backfill over reports lacking a scan record is the recovery path — state it in the spec or file it,
but do not leave "the event was missed" as an unrecoverable outcome.

**Retention defaults.** Size limit and retention period are per-environment configuration
(invariant 13); name the defaults here and mirror them in `deploy/MVP-RUNBOOK.md` when the code
lands, the way the decision-record lag alert was.

## Exit record (2026-08-14) — SPLIT

Implemented test-first and merged to backend main at **49d6bfa** (branch
`feat/t-0029-ci-scan-ingest`, commits d75bd64 → 49d6bfa). Per this task's own sequencing note the
exit record is split: AC1–AC9 are proven locally against tests at that pin; AC10 is the only
criterion that needs a live cluster and is deferred to T-0003's cluster lane — the same shape
T-0024 AC4 and T-0028 AC4 recorded.

**AC1–AC9, one line of proof each (backend@49d6bfa):**

- **AC1** — `modules/ci/internal/reportstore`: one durable object per attempt, addressed by
  `(tenant, repository, job, attempt, scanner class)`; a second report for a class an attempt
  already has is refused, and a cross-tenant read is coarse not-found.
- **AC2** — `modules/security/internal/app/ci_ingest.go`: the subscriber correlates via
  `Jobs.Get` (`ScanJob`) and sets `Revision: job.CommitSHA` — never from the report or the event.
- **AC3** — the ingest runs as the job's triggering principal (`ActorID`/`ActorRoles` from the job)
  and is PDP-decided; the report's identity fields are ignored on all axes.
- **AC4** — the no-report path is a strict no-op asserted with **zero resolutions**: no scan is
  created and no finding is opened or resolved.
- **AC5** — a failed or cancelled job's report ingests like any other; the terminal state is
  recorded, never used to filter (see implementation note (a) below).
- **AC6** — the request ID is derived deterministically as `ci:<job>:<attempt>:<class>` and replays
  through the existing scan-chunk idempotency; the `ci:` prefix is reserved and refused from wire
  callers exactly as `audit:` is (`d366911`).
- **AC7** — the report store reads `maxBytes+1` and refuses an oversized report whole at write time
  (`ErrScanReportTooLarge`), never truncating.
- **AC8** — an unparseable or unknown-class report is rejected via a `findings.scan_report_rejected`
  audit record and changes no finding.
- **AC9** — the retention sweep (`ids.TimeOf` over the attempt ULID + objectstore `List`/`Delete`)
  deletes aged reports only; findings, scans and audit records outlive the source.

**AC10** — end-to-end freshness on the composition needs a pipeline actually finishing on a live
cluster, which needs scan dispatch and the gVisor RuntimeClass the dev host lacks. Recorded as a
cluster-lane deferral against T-0003, not as a met criterion — identical to T-0024 AC4 / T-0028 AC4.

**Implementation notes:**

- **(a) Terminal state rides on the provenance audit events.** The findings scan record carries no
  terminal-state field and no contract change was allowed (SPEC-0037 "Contracts touched: none"), so
  the job's terminal state is recorded on the audit events `ci.scan_report_ingested` /
  `findings.scan_report_rejected` (`platform/audit/ci_scan.go`). The replay guard keeps emission
  exactly-once per `(job, attempt, scanner class)`.
- **(b) Backfill DISCHARGES this task's backfill open question.** The recovery sweep does not filter
  to reports lacking a scan record; it re-runs idempotent ingest over **ALL** stored reports, and
  replay dedups through the derived request ID (`ci:<job>:<attempt>:<class>`). "The event was
  missed" is therefore a recoverable outcome, not an open question.
- **(c) Retention/size defaults named** (invariant 13), mirrored into `deploy/MVP-RUNBOOK.md`
  separately: `GITFROK_CI_SCAN_REPORT_MAX_BYTES=16777216` (16 MiB),
  `GITFROK_CI_SCAN_REPORT_RETENTION_DAYS=30`, `GITFROK_CI_SCAN_SWEEP_INTERVAL=5m`.
