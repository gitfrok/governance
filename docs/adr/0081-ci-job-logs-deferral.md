# ADR-0081: CI job logs remain deferred — what reopens them is a user, an observed bypass, or an owned redaction capability, not the PRD row

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** platform (drafted under the standing instruction to give ADR-held deferrals their own
  ADR; acceptance at PR review is the decision gate)
- **Related:** ADR-0072 (the deferral this disposes the first follow-up of; Accepted, not amended),
  ADR-0070 (the Tier-B gate whose philosophy this applies), ADR-0005/0012 (the sandbox PR-11
  destroys — invariant 3), ADR-0059 and SPEC-0037 (the runner-persists precedent), ADR-0009/0010
  (residency), ADR-0008/0061 (fair-use and metering), ADR-0006 (the PDP),
  [SPEC-0054](../specs/SPEC-0054-pipeline-runs.md) (AC8, AC11), [PRD](../product/PRD.md) PR-26,
  PR-11, §6, §10, check 13 in `../../scripts/check-contracts.sh`
- **Governs:** PR-26's log half — the half ADR-0072 deliberately did not deliver

## Context

Four records describe the same absence, and they agree.

**PR-26's text.** *"A developer can see pipeline runs and job logs for a repository, scoped by the
same permissions as the repository read."* Read carefully, this is a **read surface with an
isolation commitment** — its G column is G1, its ADRs are 0070 and 0005 — not a retention
mechanism. It names no capture, no redaction, no retention, no store, and it is Phase 4: outside
the GA bar, which is PR-1…PR-19 (PRD §10). The runs half is delivered (SPEC-0054, T-0059…T-0061);
this ADR is about the rest.

**ADR-0072's decision 4.** Job output does not exist anywhere — PR-11 destroys the sandbox at job
end (invariant 3) and `api.Job` records raw output as deliberately withheld. SPEC-0020's line that
logs are *"bounded operational output with credential redaction"* describes a class, not an
artifact: nothing was ever asked to keep them, and nothing does. Retaining output is a new thing to
keep, and ADR-0072 named what the retaining decision must cover — **capture, redaction, retention
and size, access, residency** — and declined to answer any of them inside a decision about runs.

**Phase 4's record.** EP-26 shipped the runs surface and recorded that "PR-26's logs … are NOT
delivered — a deferred decision with its own ADR, held by a contract gate rather than by intention"
([backlog](../backlog/README.md), EP-26). The gate is check 13 in
`../../scripts/check-contracts.sh`: `gitsaas.ci.v1.CIJob` carries no output field, asserted against
the compiled descriptor and paired with a fixture, so the deferral is a type property of the runs
message (SPEC-0054 AC8), and the view states the absence in words rather than implying it
(SPEC-0054 AC11).

**What has changed on the demand side since ADR-0072 was Accepted 2026-08-19: nothing.** The
deferral is a day old at this writing. There is no customer, no design-partner request, and no
observed instance of anyone reaching for logs around the surface. This ADR exists because the
standing instruction is to give ADR-held deferrals an explicit trigger — not because the merits
moved.

**What has changed on the cost side: one thing, and it is not the hard part.** Capture is no longer
a story with no precedent. ADR-0059 opened the runner-persistence seam for scan reports: a
tenant-scoped object on the data-plane's object store keyed by tenant, repository, job and attempt,
size-limited with a whole refusal, under a retention sweep (SPEC-0037). Retained logs could ride
that seam. But capture was never the question that blocked ADR-0072 — the other four were, and of
those:

- **Redaction has no honest answer yet.** Pattern-based scrubbing is a promise the product cannot
  keep (ADR-0072's refused alternative), and no other mechanism is on the books.
- **Access has a contradiction in it.** PR-26 says "the same permissions as the repository read";
  ADR-0072 records that the set entitled to raw build output "is not obviously the same set that
  may read the repository" — build logs are the single most reliable place in a CI system for a
  credential to end up.
- **Retention and size are a fair-use dimension** (PRD §6) that §6 does not name and PR-23's
  metering does not measure.
- **Residency is the one question answerable now**, because the answer is "where tenant data
  already lives" — decision 5 answers it.

## Decision

**1. CI job logs remain deferred.** No log retention, no log read surface, and no field, link or
"coming soon" gesturing at one — SPEC-0054's out-of-scope clause stands as written. PR-26 stays
open, neither delivered-in-part nor withdrawn, consistent with ADR-0072's instruction that anyone
reading the roadmap see it as open rather than met.

**2. This ADR does not amend ADR-0072.** Accepted ADRs are immutable (ADR-0001, invariant 11); this
is the disposition of its first follow-up. ADR-0072's two refusals — no unredacted logs behind
`repo.read`, no regex-redaction promise — stand and bind the reopen.

**3. The deferral keeps being held by construction where construction exists.** Check 13 holds the
field path: no output field may arrive on the runs message, and the paired fixture proves the check
can fail. Its mechanical reach ends there — it asserts the `CIJob` descriptor, so a separate log
RPC is held by this decision and the spec-first rule rather than by a grep. Both holds move only in
the governance PR that implements an Accepted reopen (invariants 21, 24), and extending check 13 to
cover the RPC path is part of that PR.

**4. The reopen trigger is named, and any one of the three suffices.**

- **A user asks.** A design partner or customer names a workflow in which debugging a failed job
  needs log access inside this product. The evidence standard is the tier gate's: a user, not a
  mockup, not an internal assumption about what a forge should have. An evaluation walk-away caused
  by the missing logs counts even if the word "logs" never appears in the feedback. Pre-GA the
  design-partner channel is the demand channel (PRD §10).
- **A bypass is observed.** Anyone reaches job output by a path that goes around the product's
  access control — cluster or pod access on the data plane, runner hosts, output exported to a tool
  with no tenancy concept. That is the harm ADR-0072's risk section predicted: deferral that is
  cautious about disclosure and reckless about usefulness. Once observed, the deferral is making G1
  and G2 worse rather than protecting them, and ADR-0072's own instruction applies — take the
  decision quickly.
- **Redaction becomes an owned capability.** The secrets-scanning machinery behind PR-13's findings
  model — the Security module already redacts secret values out of its findings' identity input set
  — extends to build output such that a scrubbing claim becomes testable rather than promissory.
  The largest unresolved cost then drops, and the reopen becomes a decision with a mechanism to
  argue from instead of a promise to make.

**Not a trigger:** the PRD row, the prototype, the fact that competing forges ship logs, or
internal convenience. All were known on 2026-08-19 and weighed in the deferral; ADR-0070's gate
philosophy is again the reason — scope is defended on its merits at decision time, and a row is not
a user. The table-stakes argument is real and is treated as the risk it is in the Consequences, not
dismissed from the trigger list.

**5. Two of ADR-0072's five questions are answered now, and the rest get floors.** Fixed shape for
the day a trigger fires, in the same posture ADR-0078's decisions take toward a surface that does
not exist yet: these bind that day, and not before.

- **Capture.** Retained output leaves the sandbox only by the runner-persistence seam ADR-0059
  opened — written at or before job end, keyed by tenant, repository, job and attempt, size-limited
  with a whole refusal (nothing truncated, nothing stored), under a retention sweep. The sandbox
  still dies at job end; invariant 3 is untouched. Live streaming remains an option *inside* the
  reopen but is not an end-run around this decision: live output is job output, the access rule
  attaches to it, and it needs a path out of a sandbox PR-11 requires isolated.
- **Residency.** Retained logs are tenant data on the data-plane object store — the same class and
  placement as CI scan reports — so they follow the residency pinning ADR-0009/0010 already impose
  on tenant data. Logs add no new residency question; this one is closed rather than carried.
- **Access floor.** PR-26's "same permissions as the repository read" is a **floor, not the rule**:
  logs are never readable by anyone who may not read the repository, and the reopened decision may
  narrow further. The readable set is PDP-derived at request time, one decision per candidate, with
  no caller-assertable scope — the shape `ListJobs` already has (SPEC-0054 AC4) — and a log across
  a boundary is absent, not refused with a reason. The reopen must name the set explicitly;
  "repository readers" is a candidate, not the default, because ADR-0072's finding stands.
- **Retention.** Bounded by construction — a per-job size limit and a sweepable retention period —
  and metered under PRD §6 at reopen, either folded under an existing dimension or added as one,
  decided there with the PRD amendment. Unbounded retention is not a shape logs may arrive in.
- **The redaction claim.** The reopen either ships a mechanism it can prove and scopes the claim to
  that mechanism, or it claims nothing and says so prominently. The middle — promising scrubbing on
  the strength of patterns — remains refused (ADR-0072's second alternative).

**6. On acceptance, the PRD gets the annotation its sibling deferrals carry.** PR-26's Phase-4 row
and §12.1 gain the "Closed as deferred — held by check 13" record the way PR-29, PR-30 and PR-31
carry theirs. The PRD is amended at acceptance, not by this proposal.

## What this does not decide

- **The access set.** The floor is fixed; the set is the reopen's.
- **The wire shape.** RPCs, messages, BFF routes and the view are a spec after the reopen; check 13
  moves only in the governance PR that implements it (invariant 24).
- **Whether logs ever stream live.** Remains an option inside the reopen, with ADR-0072's caveat
  intact: streaming answers nothing after the job ends, which is when people look.
- **Anything about the shipped runs surface.** SPEC-0054's increment is untouched, including its
  honesty rule that the absence is stated in words.
- **ADR-0072's other follow-up** — whether run history itself is a fair-use dimension — which stays
  open on its own.

## Consequences

**Good.** The deferral stops being open-ended drift: it has triggers someone can observe, a shape
that answers two of the five questions outright, and floors on the rest, so the reopen starts
smaller than a blank page. The gate keeps failing loudly on erosion, and the honesty statement on
the runs surface stays true rather than becoming "coming soon" by drift.

**Bad.** PR-26 stays open, and ADR-0072's "bad" stands unsoftened: the first question a developer
asks of a failed job is *why*, and the surface does not answer it. A pipelines view that cannot say
why is a genuinely diminished thing, and this ADR adds no capability — only edges around one.

**The risk this ADR is most likely to be wrong about.** Table stakes. Every competing forge ships
build logs, and a user may never ask for what they assume they have — the gap surfaces at
evaluation as churn rather than as a request, and trigger (a) waits for words nobody may say. The
mitigations are written into the triggers: an unworded walk-away counts as an ask, and trigger (b)
catches the failure mode as soon as it does real harm. If the product loses a deal to a forge with
logs and neither trigger was ever recorded, the decision to revisit is this one. One honest note
beside: this deferral is a day old at this writing and defends a decision on which nothing has
changed — if it is wrong, it will be wrong quickly, and the triggers are how it will find out.

## Alternatives considered

**Build now — retained raw logs behind `repo.read`, no redaction claim.** ADR-0072 already refused
this and the refusal stands: `repo.read` is a wider set than the people entitled to a build's raw
output, and the first credential in a build log is not a hypothetical. PR-26's own G1 commitment is
the reason not to.

**Build now — with regex redaction.** Refused as a promise the product cannot keep (ADR-0072's
second alternative); a surface claiming "secrets removed" is worse than one claiming nothing,
because a reader stops checking. Nothing since 2026-08-19 has made the promise keepable — trigger
(c) names what would.

**Build now — live streaming only, no retention.** Genuinely attractive and still a live option,
but at reopen rather than now: it answers nothing after the job ends, which is when people look; it
still needs the access decision and a path out of a PR-11-isolated sandbox; and it satisfies the
letter of PR-26 while not satisfying the debugging workflow the row exists for.

**Withdraw the log half the way PR-32 was withdrawn.** Refused. PR-32 was withdrawn because nobody
could start it from this repository; logs are buildable, the requirement is real, and the question
is when. Deferral with a trigger is the honest middle — the same standard ADR-0082 applies to
PR-27's authoring half.

**Decide access, redaction and retention now so a build would be mechanical.** Gold-plating on zero
demand: those questions have no user, no incident and no mechanism to argue from yet, and answering
them anyway is the class of work ADR-0070's gate exists to refuse. They are left to the reopen
deliberately, where one of the three will exist.

## Follow-ups

- On acceptance: annotate the PRD's PR-26 row and §12.1 (decision 6).
- On any trigger firing: a new ADR answering the remaining questions from decision 5's floors —
  then a spec, then the governance contract PR that moves check 13 — in that order (invariant 24).
- Give the trigger an observer: design-partner feedback, and any observed cluster-side reach for
  job output, is reviewed against decision 4, so demand arrives as a reopening rather than as churn
  — or as an incident.
- ADR-0072's second follow-up — run history as a fair-use dimension — is unaffected and stays open.
