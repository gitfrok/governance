# T-0029: CI scan report → findings ingest (`CIJobFinished` wiring)

- **Status:** Todo
- **Phase / Epic:** 2 carry-over / EP-11 (findings plane), closing the path EP-7 and EP-11 never joined
- **Repo(s):** governance (SPEC-0020 amendment, if the deferral note needs restating), then backend
  — ADR-0027 order, one commit per repo
- **Spec:** docs/specs/SPEC-0037-ci-scan-report-handoff.md (Draft — must be Approved before RED)
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

- [ ] AC1: report objects are durable, tenant-scoped, and addressed by
      `(tenant, repository, job, attempt, scanner class)` — one object per scanner class per attempt.
- [ ] AC2: the subscriber ingests off `CIJobFinished`, taking the revision from `Jobs.Get`'s
      `CommitSHA`, never from the report or the event.
- [ ] AC3: the ingest runs as the job's triggering principal and is PDP-decided; the report asserts
      no identity.
- [ ] AC4: a job with no report changes nothing — and resolves nothing.
- [ ] AC5: a failed or cancelled job's report ingests like any other.
- [ ] AC6: redelivery ingests once, via a request ID derived from `(JobID, AttemptID, class)`; the
      derived prefix is refused from wire callers exactly as `audit:` is.
- [ ] AC7: an oversized report is refused at write time, never truncated.
- [ ] AC8: an unparseable report fails loudly, audited, and changes no finding.
- [ ] AC9: retention deletes reports without touching derived findings, scans or audit records.
- [ ] AC10: end-to-end on the composition — pipeline finishes, findings appear on the dashboard and
      the merge request, freshness measured.

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
