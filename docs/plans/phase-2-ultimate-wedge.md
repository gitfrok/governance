# Plan — Phase 2: the Ultimate wedge

**Status:** **Complete (2026-08-14)**
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

| # | Criterion | Verdict (2026-08-14) |
|---|---|---|
| 1 | T-0022…T-0028 (as filed) Done in `../tasks/README.md` | **met** — all seven Done at the exit pins |
| 2 | the scenario above passes on the dev cluster, with any step that cannot be demonstrated there recorded as a host limit against T-0003's cluster lane, not as a met criterion | **met with recorded host limits** — every scenario step is proven live at the exit pins (mapping below); the dev-cluster bring-up itself is infrastructure-bound on this host (interactive mkcert/ingress step, and the Phase-1 gVisor RuntimeClass limit still stands), recorded against T-0003's cluster lane |
| 3 | CI gates green per `../process/ci-gates.md` on every merged PR | **met** — super-repo gates green on the pin target: verify, surfaces-check, codegen-check, policy-check + policy-composition, lint-shell, portability-check, OPA bundle tests; per-repo suites green (see below) |
| 4 | **findings freshness** — scan results visible on the MR within one pipeline duration (PRD §9) | **host limit** — the freshness bound is measurable only with CI-dispatched scans running live on a gVisor-capable cluster (T-0017/T-0003 lane); the mechanism is tested, the measured bound is deferred — same recording shape as Phase 1 (T-0024 AC4) |
| 5 | **time-to-audit-evidence** — a dated evidence pack produced without engineer involvement, measured in hours (PRD §8) | **met** — pack generation is a single authenticated RPC with no engineer in the loop; TestLiveEvidencePackProof produced and verified a date-ranged pack at the exit pins in seconds, far inside the hours bound |

### Exit verdict (2026-08-14)

**Scenario evidence mapping.** The exit scenario passed at the exit pins — backend **0a2097c**, bff
**b7c3763**, webfrontend **7997c7c**, governance at the status-docs commit atop 450cded. All four
pins are commits on each submodule's `main`: the Phase-2 stacks landed on `main` by fast-forward
(ADR-0053/0054 direct-to-main workflow) before the super-repo re-pinned — backend main 0a2097c
contains the T-0028 merge commit 6b66da4's content, bff main b7c3763, webfrontend main 7997c7c,
and governance main carries this verdict:

| Scenario step | Evidence at the pins |
|---|---|
| scan runs on an MR → finding appears inline | attribution engine + `GetMergeBase` (backend@c64e6a3) + inline rendering (webfrontend@92804eb); live scanners (Semgrep + gitleaks) ran against a real repository in `TestLiveIdentityProof` |
| policy blocks the merge, recording the deciding version | T-0025 decision records + merge gate composed through the live policy stack: super-repo composition harness ran the real BFF PEP → gRPC → backend PDP → Rego bundle path with `merge-findings-clean` ALLOW and `merge-findings-missing-facts` fail-closed DENY |
| triage survives a re-scan | two live scans over one repository in `TestLiveIdentityProof`: stable identity, triage state carried across the re-scan |
| date-ranged pack with zero attested control records | `TestLiveEvidencePackProof` — T-0018 AC19 carried verbatim as T-0026 AC2 and proven live |
| auditor opens the pack under a scoped, time-boxed grant, no repo read | `TestLiveAuditorGrantProof` — open under an ACTIVE grant, every repository action denied (audited), denied again after expiry/revocation |
| search filtered to the caller's permissions | full codesearch suite at 6b66da4, including the differential leak test (unauthorized-only query indistinguishable from no-match) and revocation-binds-on-next-query |

**Per-repo gates on the pin target:** backend go build + go vet + full `go test ./...` (with
Postgres integration suite) green; bff go build + go vet + full suite green; webfrontend
`npm run check` + tests + build green; governance contract/policy checks green.

**Pin note:** T-0028's independent backend branch (267eaa4) was merged into the findings-plane stack
tip (merge commit 6b66da4) because the super-repo holds one pointer per submodule; the full suite
re-ran green on the merge target.

**Re-pin note (fix wave, 2026-08-14):** the exit review found super-repo commit 1f2f453 pointed all
four pins (backend 6b66da4, bff b7c3763, webfrontend 7997c7c, governance 06f7256) at commits
reachable only via feature branches, violating the "merged commits only" rule (super-repo AGENTS.md
§5). The fix wave merged each stack into its submodule's `main` — governance c0cc78b→e0be758,
backend 29a9914→0a2097c, bff 4693eae→b7c3763, webfrontend 5bb110a→7997c7c, all fast-forward, no
force-push — and the super-repo re-pins to those merged `main` tips. The provisioning fix that
preceded this (super-repo 827afa5) made dev-provision.sh apply the full 9-migration set, re-verified
here against a throwaway Postgres with every Phase-2 table and the audit evidence indexes present.

**Carried forward:** the `/api/v1` vs bare `/v1` BFF route-prefix deviation (routing hygiene, not a
correctness gap — see `../backlog/README.md`); bff `gen/proto/policy/v1` was regenerated at exit to
satisfy `codegen-check` although the pinned BFF work consumes only `Decide`; and the infrastructure-
bound steps (CI-dispatched scans, measured freshness bounds, live-cluster scenario walk) remain
against T-0003's cluster lane.

**Operational notes recorded at exit** (full detail in the super-repo's `deploy/MVP-RUNBOOK.md` §4a):
(a) the security merge gate engages on every storage-backed plane once the security migrations are
applied and denies merges whose head or base lacks an ingested scan — rollout prerequisite is scan
coverage before enabling it on existing repositories, and no scan-dispatch path exists in dev yet;
(b) the MR-findings projection is in-process memory, so a dataplane restart merge-blocks MRs opened
before the restart until a new push/retarget re-emits the events — startup seeding from the durable
stores is a follow-up against the findings plane; (c) the decision-record append sits on the `Decide`
hot path and fails closed — an operational availability contract: monitor decision-record append
failures, because a failing append reads as a plane that denies everything.

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
