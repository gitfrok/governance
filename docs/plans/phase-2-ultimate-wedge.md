# Plan — Phase 2: the Ultimate wedge

**Status:** **Active (2026-08-14)**
**Objective:** the differentiating governance/security surface is usable end to end — every scanner's
output normalized into one findings model, surfaced where code is reviewed, enforced at merge by
policy-as-code, exportable as audit evidence, and searchable under the caller's permissions
(PRD §3, §5 Phase 2; roadmap §Phase 2).

Scope is exactly **PR-13…PR-19**. Nothing else enters this phase; Phase-3 BYO requirements
(PR-20…PR-23) stay out even where a workstream here makes them easier.

The roadmap and `../backlog/README.md` phrase part of this phase as "audit UI + evidence export". No
PR-# names an audit UI, and this plan does not add one: the reading surface a compliance owner and an
auditor need is **the surface of workstreams 5 and 6** — the evidence pack and its scoped, time-boxed
grant. A browsable audit-log UI beyond that is deliberately out of scope here and needs its own
requirement in a PRD revision before it is planned.

Unlike `phase-0-foundations.md` and `phase-1-mvp.md`, this plan is written before the work rather
than after it. Task files remain authoritative for status once they exist; this plan fixes scope,
order, dependencies and the exit bar.

## Workstreams

Numbering continues from Phase 1 (T-0019 is retired and never reused). The tasks below are **filed**
under `../tasks/`, grouped into epics EP-11…EP-14 in `../backlog/README.md`. Every task has its spec — **SPEC-0024…SPEC-0035**, all
**Approved (2026-08-14)**, so every task may go RED (next free: SPEC-0036). The decisions taken at
approval, including **ADR-0055** on audit retention, are recorded in `../backlog/README.md`.

| # | Workstream | Requirement | ADR anchor | Task | Epic |
|---|---|---|---|---|---|
| 1 | Normalized findings model + ingestion | PR-13 | 0015 | T-0022 | EP-11 |
| 2 | Security dashboard (repo/org) with triage state | PR-14 | 0015 | T-0023 | EP-11 |
| 3 | Findings inline on the merge request | PR-15 | 0015 | T-0024 | EP-11 |
| 4 | Security/approval policy authoring, versioning, dry-run, merge enforcement | PR-16 | 0006, 0007 | T-0025 | EP-12 |
| 5 | Evidence pack export (date-ranged, SOC 2 Type II walkthrough) | PR-17 | 0007, 0029 | T-0026 | EP-13 |
| 6 | Scoped, read-only, time-boxed auditor access | PR-18 | 0006 | T-0027 | EP-13 |
| 7 | Permission-filtered code search | PR-19 | 0014 | T-0028 | EP-14 |

**Workstream 1 — findings model (PR-13).** One normalized model across SAST, dependency, secrets,
container and DAST scanners, with **stable finding identity across scans** — the identity rule is the
hard part and everything downstream depends on it: triage state that survives a re-scan (PR-14),
inline placement on the MR that introduced a finding (PR-15), and the scan-gate records an evidence
pack cites (PR-17). Scanner *selection* is an implementation choice, not a commitment of this plan
(PRD §12.4); the ingestion boundary is a contract, so scanners are pluggable behind it.

**Workstream 2 — dashboard (PR-14).** One surface per repo and per org, filterable by severity,
class, age and owning team, with triage states accept / false-positive / fix / defer. ADR-0015 makes
the unified surface a design rule, not a preference: findings consolidate here rather than
scattering per-feature tabs.

**Workstream 3 — MR inline (PR-15).** Findings appear in the merge request that introduced them.
Depends on workstream 1's identity rule plus the introduction attribution (which change first
carried the finding).

**Workstream 4 — policy (PR-16).** A security or approval policy is authored, versioned, **dry-run**,
and enforced at merge, with the **deciding policy version recorded on the decision**. Builds on the
Phase-0 PDP (ADR-0006, SPEC-0002) and the Phase-1 merge gate (T-0016). Two constraints carry in:
SPEC-0002's cache invalidation is by bundle revision, so a policy change invalidates every cached
decision by construction; and per ADR-0029 §4, an **imported approval never satisfies a policy
requirement** — only first-party approvals gate a merge.

**Workstream 5 — evidence pack (PR-17).** Date-ranged export of approvals, policy decisions, scan
gates and access changes, sufficient for a SOC 2 Type II control walkthrough without engineer
involvement. This workstream **inherits T-0018's AC19**, restated here verbatim from SPEC-0011 AC14
because it is the criterion Phase 1 owed forward:

> A generated evidence pack over a range spanning an import contains zero attested records in its
> control sections; attested history appears only in the labeled appendix with its provenance blocks
> and the admitting `HistoryImported` event.

ADR-0029 §4 binds this surface whether or not the criterion is copied into the task that builds it.

**Workstream 6 — auditor access (PR-18).** Scoped, read-only, time-boxed access to evidence
**without repo read access** — a distinct grant, not a role that happens to be able to read less.

**Workstream 7 — code search (PR-19).** Zoekt-style dedicated index (ADR-0014), incremental off repo
events, results filtered to the caller's tenant and accessible repos, never leaking the *existence*
of unauthorized content. Near-independent of workstreams 1–6; ADR-0014's open follow-ups —
index-freshness SLO, reindex strategy, access-filter tests — belong to this task.

## Sequence and critical path

Order within each workstream follows ADR-0027: **governance → backend → bff → webfrontend →
super-repo**. Contracts, policy rules and specs land in `governance/` first, because they unblock
every consumer; no work item spans two submodules in one commit (invariants 21–25).

**Critical path:** workstream 1 (findings model + stable identity) → workstreams 2, 3 and the
scan-gate half of 4 → the scan-gate sections of workstream 5. Workstream 4's decision-recording is
what makes an evidence pack's policy-decision section real, so 4 precedes 5 even though 5 also
depends on Phase-0's audit chain (T-0006) which already exists. Workstream 6 depends on 5 having a
pack to scope. Workstream 7 runs alongside from the start and gates nothing.

Workstreams 1 and 7 can start in parallel. Nothing else should start before workstream 1's contract
is merged in `governance/`.

## The retention gate — settled by ADR-0055

**Retention of attested imported records — `ADR-0055` (Accepted 2026-08-14).** What was an open
ADR-0007 follow-up and SPEC-0011's last open item (PRD §12.3) is decided: the append-only chain never
removes anything, so no control record a pack cites can vanish; attested imported records sit outside
the chain (ADR-0029) and expire one year after import or with their repository, while the admitting
`HistoryImported` event stays chained and outlives them; and an evidence pack is a **self-contained
snapshot**, so it remains verifiable regardless of any later expiry. Workstream 5 builds against that,
and workstream 6's grants show the same content whenever they are exercised.

Parked decisions that touch this phase but do not block it: unit-economics per tier (ADR-0008) —
scan volume and code-search index size are already fair-use dimensions (PRD §6); the event catalog
(ADR-0022) — the findings and policy events add more unnamed protobuf full names to a catalog nothing
documents.

## Exit criteria

The phase exits when the following scenario passes end to end, as Phase 1's did:

**scan runs on an MR → the finding appears inline on that MR → a security policy blocks the merge and
the decision records the deciding policy version → the finding is triaged and the triage survives a
re-scan → a date-ranged evidence pack exports with zero attested records in its control sections →
an auditor opens that pack under a scoped, time-boxed grant with no repo read access → code search
returns results filtered to the caller's permissions.**

| # | Criterion |
|---|---|
| 1 | T-0022…T-0028 (as filed) Done in `../tasks/README.md` |
| 2 | the scenario above passes on the dev cluster, with any step that cannot be demonstrated there recorded as a host limit against T-0003's cluster lane, not as a met criterion |
| 3 | CI gates green per `../process/ci-gates.md` on every merged PR |
| 4 | **findings freshness** — scan results visible on the MR within one pipeline duration (PRD §9) |
| 5 | **time-to-audit-evidence** — a dated evidence pack produced without engineer involvement, measured in hours (PRD §8) |

## Risks

- **Host limits carry forward from Phase 1.** Scans ride CI v0, and the dev cluster has no gVisor
  RuntimeClass under rootless podman, so scan dispatch may be demonstrable only on T-0003's cluster
  lane (T-0017). Phase 1 hit exactly this shape; record it at planning time rather than rediscovering
  it at exit.
- **Finding identity is the phase's single point of failure.** If identity is not stable across
  scans, triage state, MR attribution and scan-gate evidence all degrade at once. Prove it against
  real scanner output on a real repository across at least two scans, not against fixtures.
- **A test against a fake proves the control flow, not the claim** — Phase 1 paid for this lesson four
  times over (`phase-1-mvp.md` §Lessons). Anything an acceptance criterion rests on gets a live proof.
- **The evidence pack is a compliance claim, not a report.** A control section that silently admits an
  attested record is a false claim to an auditor. AC19 is a blocking criterion, not a nice-to-have.
- **Scanner ecosystem churn.** Keeping scanners behind the ingestion contract is what stops a scanner
  swap from becoming a schema migration; resist per-scanner fields leaking into the normalized model.
- **Search index and permissions drift.** ADR-0014 requires enforcement on every result path; an index
  that is correct at write time and stale at read time leaks existence. Access-filter tests are part
  of the task, not a follow-up.
