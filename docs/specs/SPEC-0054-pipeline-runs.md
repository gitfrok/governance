# SPEC-0054: Pipeline runs — what a job did, and the plain statement that its output is gone

- **Status:** Implemented (2026-08-19) — every acceptance criterion is proven by its task(s); approved (2026-08-19) — ADR-0072 Accepted; RED may begin
- **Owner:** platform
- **Context(s):** CI (owns the job history) · BFF (shapes) · Web frontend (renders)
- **ADRs:** 0072 (decides this), 0071 (the durability precedent it follows), 0062, 0005, 0012,
  0070, 0069, 0006
- **Task(s):** T-0059 (backend), T-0060 (contract + bff), T-0061 (web)

## Problem / context

PR-26 asks for pipeline runs and job logs. ADR-0072 delivers the runs and defers the logs to their
own decision, because job output does not exist anywhere — PR-11 destroys the sandbox at job end and
`api.Job`'s own comment records raw output as deliberately withheld. **That decision is now taken:
ADR-0081 (Accepted) keeps the logs deferred** — what reopens them is a user asking, an observed
bypass, or redaction becoming an owned capability, never the PRD row's silence — and check 13
continues to hold the absence at the wire until then.

The CI context also has no durable job store (`memoryStore` is the only implementation) and no
`List`, so "what has run" is unanswerable twice over. This spec fixes both, following ADR-0071
exactly.

**The honesty rule on this surface is the absence of logs, and it has to be said rather than
implied.** A pipelines view that shows a failed job and no way to see why reads, to anyone who has
used a forge, as *the logs are somewhere else on this page*. They are not anywhere. The surface says
so in words, once, where a reader looking for them will be.

## In scope

- A durable, tenant-scoped CI job store behind the existing port.
- `List` on the `Jobs` port, derived server-side from the caller's authorization.
- The runs view: state, trigger, ref, commit, timings and outcome summary — the fields AC10 names.

  **Not the delay cause.** `api.Job` records why a job waited (SPEC-0041 AC5) but `CIJob` carries no
  field for it on the wire, and adding one for a fact no acceptance criterion tests would be scope
  arriving through the back door. An earlier draft of this line listed it; AC10 never did, and AC10
  is what gets tested.

## Out of scope

- **Job logs**, by ADR-0072, dispositioned by ADR-0081. Not as a field, not as a link, not as a
  "coming soon".
- Re-running, cancelling or triggering a job from this surface. Cancel exists on the port; exposing
  a write here is its own spec.
- Pod names, node details, attempt capabilities and source bytes — `api.Job` withholds them and this
  spec does not widen it.

## Contracts touched

`contracts/proto/ci/v1` — **additive**: `ListJobs` with its request and response.

## Data owned

The CI context gains a tenant-scoped `ci.jobs` table: module-owned migration, RLS on `tenant_id`.

## Acceptance criteria (each becomes a test)

### The durable store and the list (T-0059)

- [x] **AC1** A job survives the process that enqueued it: written, the store rebuilt against the
      same database, the job still readable with its state, timings and outcome intact.
- [x] **AC2** The table is tenant-scoped with RLS and its migration passes T-0004's boundary linter.
- [x] **AC3** Cross-tenant reads are absent rather than forbidden — not gettable, not listable.
- [x] **AC4** `List` returns only jobs whose repository the PDP allows, one decision per candidate at
      request time, with no caller-assertable scope. A caller allowed nothing gets an empty list,
      never an error.
- [x] **AC5** The list pages by an opaque cursor and carries **no total**.
- [x] **AC6** **The isolation proofs ran.** Zero skips for the tenancy cases; the exit record states
      the observed skip count, not merely that the run was green (carried limit 5).

### The wire and the BFF (T-0060)

- [x] **AC7** Additive: `buf breaking` passes.
- [x] **AC8** **No field on the wire carries or gestures at job output.** A descriptor test asserts
      `CIJob` and the list messages carry no field named `log`, `logs`, `output`, `stdout` or
      `stderr` — ADR-0072's deferral expressed as a type property, so it cannot erode into a
      convenience field before the log decision is taken.
- [x] **AC9** The BFF shapes and forwards under the session; one coarse refusal.

### The view (T-0061)

- [x] **AC10** Runs render with state, trigger, ref, short commit, queued/started/finished times and
      the outcome summary, reachable from the repository surface.
- [x] **AC11** **The absence of logs is stated, not implied.** The surface says output is not
      retained, and a test enumerates the copy: no rendered string may say "coming soon", "not yet
      available" or otherwise imply the logs exist elsewhere — because "we do not keep them" and
      "they are behind a door you have not found" are different facts.
- [x] **AC12** Job state carries a glyph and a word, entering `src/lib/status.ts` under the ADR-0069
      laws; a state added later with colour alone fails the enumeration test.
- [x] **AC13** No hex literal; units on every length; a refusal names no cause; the two regression
      pins unmodified.
- [x] **AC14** The stub serves the list including an empty case and a refusal; captures regenerated
      and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | RLS on the new table; AC3 and AC5 keep a cross-tenant job absent and uncountable. |
| G2 authorization | AC4 — the listable set is the PDP's, per candidate, at request time. |
| G5 auditability | Unchanged; this is a read. AC8 is the auditability criterion in the negative: nothing here starts retaining output nobody decided to retain. |

## Non-functional

- The store follows ADR-0071's shape: module-owned migration, RLS everywhere, no named exemption.

## Open questions / assumptions

1. **Run history is now unbounded.** Once durable, jobs accumulate; whether that is a fair-use
   dimension (PRD §6) is ADR-0072's follow-up and is not answered here.
2. **No log link, of any kind.** Including one that 404s would be worse than none.
