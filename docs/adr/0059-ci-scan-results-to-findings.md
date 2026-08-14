# ADR-0059: How a CI scan's results reach the findings plane

- **Status:** Proposed (2026-08-14)
- **Deciders:** platform
- **Supersedes / superseded by:** —
- **Related:** ADR-0022 (context boundaries), ADR-0025 (modular monolith), SPEC-0010, SPEC-0020,
  SPEC-0024, SPEC-0025, T-0024 AC4, T-0028 AC4, T-0003 cluster lane

## Context

Phase 2 shipped the findings plane and Phase 1 shipped CI, and nothing joins them. `CIJobFinished`
is published (`backend/modules/ci/internal/dispatcher/dispatcher.go:234`) and nobody subscribes.
Scan results reach the findings plane exactly one way today: an external caller invokes
`IngestScanResults` over gRPC. That is how the live proofs drive it, and it is why the phase exited
with the wiring recorded as unbuilt rather than deferred by choice.

Three facts constrain any answer, and each was verified in the tree rather than assumed:

1. **The event cannot correlate a scan on its own.** `CIJobFinished` carries `JobID`, `AttemptID`,
   `TenantID`, `RepositoryID`, `TerminalState`, `OutcomeSummary`, `OccurredAt` — and no revision. A
   subscriber cannot know which commit was scanned from the event alone.
2. **A job read port already exists.** `ci/api.Jobs.Get` returns a `Job` carrying `Ref` and
   `CommitSHA`, plus the triggering `ActorID`/`ActorRoles`. Correlation is therefore reachable
   without changing the event contract at all.
3. **Scanner output has no home.** SPEC-0020 states plainly that "artifact persistence is deferred";
   a job's only durable output is the bounded `OutcomeSummary` string and redacted logs. Whatever a
   scanner writes inside the sandbox is discarded when the attempt ends. `platform/objectstore`
   exists and is the storage precedent, but nothing in CI writes to it.

Fact 3 is the real gap. Correlation is a detail; the absence of any durable place for a scan report
is what makes this a decision rather than a wiring task.

The event-driven path is also what two acceptance criteria assume: **T-0024 AC4** and **T-0028 AC4**
measure findings/index freshness on a real pipeline, and freshness cannot be observed on a path that
does not exist. T-0003's cluster lane owns those demonstrations and lists this wiring first.

## Decision

**Undecided — this ADR presents the options and stops.** The recommendation is Option C.

### Option A — the scan step calls the ingest RPC itself

The job's scan step normalizes its own output and calls `IngestScanResults` from inside the sandbox.
`CIJobFinished` stays a pure announcement; nothing subscribes to it.

- Needs no contract change, no artifact store, no subscriber.
- The sandbox is a gVisor-isolated pod with restricted egress; a scan step that reaches the dataplane
  door needs that egress opened, and the door is unauthenticated (limit (d), review H2) — an
  in-cluster caller asserting its own tenant, actor and roles.
- Normalization to `RawFinding` moves into pipeline YAML, which puts a wire-format contract in
  tenants' pipeline definitions. SPEC-0024's identity rule then depends on what a tenant's pipeline
  sends.
- **It also does not satisfy the records.** T-0024 AC4 and the backlog both describe ingest *off
  `CIJobFinished`*; choosing A means amending those records to say the path is RPC-only by design.

### Option B — the dispatcher hands results to the findings plane in-process

At job completion the dispatcher passes the scan step's output through a composed port to the
Security context, in-process, before publishing `CIJobFinished`.

- No object store, no contract change, no egress question, and the identity is the job's own.
- The handoff is synchronous and unrecoverable: a plane that restarts between the attempt finishing
  and the ingest committing loses that scan's findings with no record that they existed. Every other
  Phase-2 durability decision went the other way.
- CI would carry a Security dependency in composition. That is legal at the `cmd/` seam (ADR-0022),
  but it inverts the direction every other cross-context flow uses — events out, no synchronous call
  in.
- Still not the event-driven path the ACs describe.

### Option C — the runner persists the report, a subscriber ingests it (recommended)

The scan step writes its raw report to `platform/objectstore` under a key derived from
`(tenant, repository, job, attempt)`. A Security subscriber to `CIJobFinished` resolves the job via
`ci/api.Jobs.Get` for `CommitSHA`, fetches the report, normalizes it to `RawFinding` chunks, and
calls the existing `IngestScanResults` application port in-process.

- It is the path the acceptance criteria already assume, so no record has to be amended.
- Correlation needs **no contract change**: `Jobs.Get` supplies the revision. The event may later be
  enriched additively if the extra read proves costly, but nothing here requires it.
- Idempotency is free: a deterministic `RequestID` per `(JobID, AttemptID)` rides the replay
  machinery scan ingest already has. **Constraint:** that ID must not enter the reserved marker
  namespace — the ingest boundary refuses a request ID beginning `audit:` (review N2), and any new
  prefix this introduces (`ci:`, say) must be reserved the same way, in the same place.
- The durable report is worth having on its own: it is what makes a finding re-derivable and a
  disputed scan re-checkable.
- **Cost:** it un-defers artifact persistence, which SPEC-0020 deliberately deferred. That deferral
  has to be revisited in a SPEC-0020 amendment — retention, size bounds, and tenant scoping of the
  stored report are all open, and ADR-0055's retention rules do not cover it (a scan report is not
  an audit record).

### What every option must answer regardless

- **Principal.** Event-driven ingest still passes `validContext` and a PDP decision. The job carries
  the triggering `ActorID`/`ActorRoles`; using them attributes the ingest to the human who pushed,
  while a system principal attributes it to the plane. SPEC-0025's vocabulary and invariant 2 decide
  this, and the choice is visible in every audit record the ingest writes.
- **Failed and cancelled jobs.** `TerminalState != SUCCEEDED` may still have produced a complete
  scan report — a scanner exiting non-zero *because* it found breach-level findings is the normal
  case. Ingesting only on success would silently drop exactly the findings that matter most.
- **No report present.** A job that ran no scan step must be an ordinary no-op, not an error and not
  an empty scan: an empty ingested scan resolves every open finding for that tool (SPEC-0024
  lifecycle), which would be a data-destroying default.

## Consequences

Choosing C unblocks T-0024 AC4 and T-0028 AC4 on the cluster lane and gives Phase 2's last unbuilt
path a home, at the cost of reopening SPEC-0020's artifact deferral and adding a storage surface
with its own retention question. Choosing A or B closes the gap faster and requires amending the
records that describe the path as event-driven.

Whichever is chosen, this ADR does not authorize code: the work needs a task and an amended or new
spec (SPEC-0024/0025 own the ingest contract; SPEC-0020 owns the job's output surface) before RED.
