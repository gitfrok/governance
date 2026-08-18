# ADR-0072: CI keeps a durable job history; job logs are a separate decision it does not make

- **Status:** Accepted
- **Date:** 2026-08-19 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform (found while scoping PR-26, ADR-0070 Tier B)
- **Related:** ADR-0071 (the same finding for the repository registry), ADR-0062 (the durability
  precedent), ADR-0005 and ADR-0012 (CI sandboxes), ADR-0058 (the pipeline format), ADR-0070,
  ADR-0022, ADR-0006
- **Governs:** PR-26 (pipelines and job logs in the web UI), and PR-11's browser half

## Context

PR-26 asks for pipeline runs **and job logs** in the web UI. Scoping it found two facts, and they
are not the same size.

**The CI context has no durable job store.** `modules/ci/internal/app` holds a `memoryStore`, and
nothing else implements the port. This is the third instance of the shape ADR-0062 addressed for the
agent and residency stores and ADR-0071 addressed for the repository registry: a context whose
record of what happened lives in a process. There is also no `List` — `Jobs` has `Enqueue`, `Get`
and `Cancel`, so nothing can answer "what has run".

**Job logs do not exist anywhere, and their absence is a design, not a gap.** `api.Job`'s own
comment enumerates what the public view withholds: *"Attempt capabilities, pod names, node details,
**raw output**, and source bytes are CI implementation details."* PR-11 requires each job to run in a
fresh isolated sandbox **destroyed at job end**, so there is no artifact to fetch after the fact and
no store that was ever asked to hold one.

Retaining job output is therefore not a read that was forgotten. It is a new thing to keep, and it
is the single most reliable place in a CI system for a credential to end up: build tooling echoes
environment, package managers print tokens in URLs, a failing test dumps a fixture. Every forge that
has shipped logs has also shipped a redaction story, a retention policy and an access rule, usually
in that order and usually after an incident.

## Decision

**1. The CI job store becomes durable, behind the existing port.** A tenant-owned table with RLS and
a module-owned migration, exactly as ADR-0071 did for the repository registry and ADR-0062 for the
agent and residency stores. The port is unchanged; this is the adapter.

**2. `Jobs` gains `List`, and its result is derived server-side by the PDP** — one decision per
candidate job's repository, at request time, with no caller-assertable scope. The same shape the
repository list and code search already have.

**3. The list carries no total**, for the reason it carries none elsewhere: no field may be capable
of expressing how many runs the caller may not see.

**4. Job logs are OUT of this decision, and PR-26's log half is not delivered by it.** This ADR
delivers *pipeline runs*; it explicitly does not deliver *job logs*, and it declines to smuggle them
in as a field on a run. Retaining job output needs its own decision covering, at minimum:

- **what is captured** and from where, given the sandbox is destroyed at job end;
- **redaction** — what is scrubbed before anything is stored, and what the product claims about it,
  because "we redact secrets" is a promise that is wrong the first time a tool invents a new format;
- **retention and size**, which are fair-use dimensions (PRD §6) and therefore metering questions;
- **who may read them**, which is not obviously the same set that may read the repository;
- **residency**, since logs are tenant data and ADR-0009/ADR-0010 pin where tenant data lives.

Until that decision exists, the pipelines surface shows what a run *did* — state, timing, trigger,
commit, outcome summary — and says plainly that output is not retained. That is a smaller product
than PR-26 describes, and saying so is better than shipping a log viewer whose redaction nobody
decided.

## Consequences

**Good.** "What has run" becomes answerable and survives a restart. The pipelines surface can ship
without waiting on the hardest question in it, and the hardest question gets asked on its own terms
rather than as a field someone added to a response.

**Bad.** PR-26 is delivered in half. A pipelines view without logs is a genuinely diminished thing —
the first question a developer asks of a failed job is *why*, and this surface will not answer it.
Anyone reading the roadmap should see PR-26 as open, not met.

**The risk this ADR is most likely to be wrong about.** That deferring logs is the cautious choice.
It is cautious about disclosure and reckless about usefulness: a CI surface that cannot show why a
job failed may push people back to `kubectl logs`, which has none of the access control this
deferral is protecting. If that happens, the deferral has made things worse, and the answer is to
take the log decision quickly rather than to quietly add a log field here.

## Alternatives considered

**Ship logs now, unredacted, behind `repo.read`.** Refused. The first credential in a build log is
not a hypothetical, and `repo.read` is a wider set than the people entitled to a build's raw output.

**Ship logs now with regex redaction.** Refused as a promise the product cannot keep. Pattern-based
redaction fails on the formats it has not seen, and a surface that claims "secrets removed" is worse
than one that claims nothing — a reader stops checking.

**Stream logs live without retention.** Genuinely attractive and still a decision: it needs a path
out of a sandbox that PR-11 requires to be isolated, and it answers nothing after the job ends,
which is when people actually look. Recorded as an option for the log ADR rather than dismissed.

## Follow-ups

- The job-log decision itself, covering capture, redaction, retention, access and residency.
- Whether run history is a fair-use dimension (PRD §6) once it is durable and therefore unbounded.
