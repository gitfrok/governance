# PRD — Multi-tenant Git SaaS

- **Status:** Draft
- **Scope:** whole product, phased (Phases 0–3 per `../roadmap/README.md`)
- **Constraining ADRs:** 0003, 0004, 0005, 0006, 0007, 0008, 0009, 0010, 0011, 0012, 0013, 0014,
  0015, 0016, 0017, 0018, 0022, 0023, 0024, 0025, 0026
- **Relation to SoT:** `../adr/` is the Source of Truth (ADR-0001). This PRD states **product
  requirements only**. Where it appears to decide architecture, it is *restating* an Accepted ADR.
  Any requirement here that cannot be satisfied without a new architectural decision is listed in
  §12 as needing a **Proposed ADR** — not resolved in this document.

---

## 1. Problem

Regulated engineering organizations run source hosting, code review, CI, and a scattered set of
security scanners as separate products. Findings land in four consoles, none of them the one where
code is reviewed. Producing audit evidence — who approved what, which scan gated which merge, which
policy was in force on a date — is a manual, weeks-long exercise. Consumption-priced CI makes cost
unpredictable, and data-residency obligations push these teams toward self-hosting, which they lack
the staff to operate.

## 2. Target customer (ICP)

**Beachhead:** regulated mid-market engineering organizations, **50–500 developers** — fintech,
healthtech, insurtech, gov-adjacent. Traits: a compliance program already exists (or is being
stood up), an auditor asks for evidence at least annually, data-residency or region-pinning is
contractual, and platform headcount is 1–5 people.

Out of beachhead (serve later, do not design for): <10-dev startups, air-gapped enterprises
(see §7 non-goals), non-managed-Kubernetes self-hosters.

### Personas

| Persona | Owns | Primary pain | Primary surface |
|---|---|---|---|
| **Platform engineer** (buyer/operator) | the install, upgrades, envelopes | operating hosting + CI + scanners with 1–5 people | admin, policy authoring, fleet/release (ADR-0013) |
| **Security lead** (champion) | findings backlog, policy | findings scattered across consoles; no merge-time enforcement | unified security dashboard (ADR-0015), policy-as-code (ADR-0006) |
| **Compliance / audit owner** (economic pain) | control evidence | assembling evidence by hand for each audit | audit UI + evidence export (ADR-0007) |
| **Developer** (daily user) | code, MRs | context-switching to security tools; slow clones | repo browser, MR review, CI (ADR-0015) |
| **Auditor** (external, read-only) | attestation | trusting a screenshot | scoped read-only evidence export |

## 3. Value proposition & wedge

Table stakes (Phase 1): host repos, review merge requests, run pipelines — GitHub-clean UX
(ADR-0015), no learning tax.

**Wedge (Phase 2):** every scanner's output normalized into one findings model, surfaced in the
same place code is reviewed, enforced at merge by policy-as-code, and exportable as audit evidence
from an append-only trail. One product answers "is this change safe to merge, and can you prove it."

Supporting differentiators:
- **Flat-rate pricing** made solvent by fair-use envelopes (ADR-0008) — predictable cost, no
  per-minute CI meter.
- **BYO data plane** (ADR-0009) — customer's own GKE/EKS/AKS for residency (G7), operated by us
  through an outbound-only agent (ADR-0011), so the customer does not staff it.

## 4. Deployment model (product view)

Per ADR-0009 the control plane is multi-tenant and hosted by us; the data plane is single-tenant.

- **Default sold posture:** we host the data plane. Customer onboards with no infrastructure work.
- **BYO data plane:** available as an option from GA (Phase 3), in the customer's GKE/EKS/AKS only
  (ADR-0010), packaged as Helm + Operator (ADR-0013), reached only by outbound gRPC/mTLS from the
  customer's cluster (ADR-0011, ADR-0017). Signed releases only.
- The customer-visible product surface is identical in both postures. Any capability that works in
  one and not the other is a defect, not a tier.

## 5. Requirements by phase

Requirements are numbered `PR-#`. Each maps to existing roadmap phases, backlog epics, and specs.
"New" in the Task column means no task exists yet (see §12).

### Phase 0 — Foundations (internal; no customer-visible surface)

| ID | Requirement | G | ADR | Spec / Task |
|---|---|---|---|---|
| PR-1 | Every persisted row and every query is tenant-scoped; cross-tenant access is impossible by construction, not by convention | G1 | 0003 | SPEC-0001 / T-0004 |
| PR-2 | Every sensitive action is authorized by a deny-by-default decision point before it takes effect | G2, G4 | 0006 | SPEC-0002 / T-0005 |
| PR-3 | Every sensitive action emits an audit event that cannot be altered or deleted | G5 | 0007 | SPEC-0003 / T-0006 |
| PR-4 | Repo storage backing is chosen on measured evidence before Phase-1 storage work begins | — | 0016, 0023, **0033** | T-0007 **Done** (measured + decided 2026-08-06; evidence `../bench/T-0007/`) |

### Phase 1 — MVP (GitHub-lite)

| ID | Requirement | G | ADR | Spec / Task |
|---|---|---|---|---|
| PR-5 | A developer can clone, fetch, and push over HTTPS and SSH with an org identity or a scoped token | G2 | 0004, 0023 | SPEC-0004, SPEC-0006 / T-0011, T-0013 |
| PR-6 | An accepted push is durable: acknowledged only after the primary and one synchronous replica hold it | — | 0016 | SPEC-0005 / T-0012 |
| PR-7 | On loss of the primary, service resumes automatically from an in-sync replica; on dual loss the repo goes read-only and only an audited operator override can force-promote | G5 | 0016, 0018 | SPEC-0005 / T-0012 |
| PR-8 | A developer can browse repo tree, file contents, blame, history, and diffs in the web UI | — | 0015 | SPEC-0007, SPEC-0008 / T-0014, T-0015 |
| PR-9 | A team can open, review, comment on, approve, and merge a merge request | G4 | 0015 | SPEC-0009 / T-0016 |
| PR-10 | Branch protection and approval requirements are enforced server-side and expressed as policy, not UI toggles | G4 | 0006 | SPEC-0009 / T-0016 |
| PR-11 | A pipeline runs on push and on MR, each job in a fresh isolated sandbox destroyed at job end | G1 | 0005, 0012 | SPEC-0010 / T-0017 |
| PR-12 | A customer can import a repository from GitHub or GitLab — refs, tags, LFS objects, **and** pull/merge request history with review threads, approvals, and their authors and timestamps | — | 0004, 0007 | **New** (§12.1) |

### Phase 2 — Unified security & governance (the wedge)

| ID | Requirement | G | ADR | Spec / Task |
|---|---|---|---|---|
| PR-13 | Scanner output (SAST, dependency, secrets, container, DAST) is normalized into one findings model with stable identity across scans | G3 | 0015 | **New** |
| PR-14 | One dashboard shows all findings for a repo/org, filterable by severity, class, age, and owning team, with triage state (accept, false-positive, fix, defer) that survives re-scan | G3 | 0015 | **New** |
| PR-15 | Findings appear inline in the merge request that introduced them | G3, G4 | 0015 | **New** |
| PR-16 | A security or approval policy can be authored, versioned, dry-run, and enforced at merge, with the deciding policy version recorded on the decision | G4, G6 | 0006, 0007 | **New** |
| PR-17 | A compliance owner can export a date-ranged evidence pack — approvals, policy decisions, scan gates, access changes — sufficient for a **SOC 2 Type II** control walkthrough, without engineer involvement | G5, G6 | 0007 | **New** |
| PR-18 | An auditor can be granted scoped, read-only, time-boxed access to evidence without repo read access | G2, G6 | 0006 | **New** |
| PR-19 | Code search returns results filtered by the caller's permissions, never leaking existence of unauthorized content | G1, G2 | 0014 | **New** |

### Phase 3 — BYO & commercial

| ID | Requirement | G | ADR | Spec / Task |
|---|---|---|---|---|
| PR-20 | A customer installs the data plane into their own GKE/EKS/AKS and it self-registers to the control plane over an outbound-only connection | G7, G9 | 0009, 0010, 0011, 0013, 0017 | **New** |
| PR-21 | We ship upgrades to a customer data plane as signed releases with reconcile-based rollout and rollback, without inbound access to their cluster | G9 | 0011, 0013, 0017 | **New** |
| PR-22 | Tenant data and compute stay pinned to the tenant's declared region/cloud, and that pinning is demonstrable in the evidence pack | G7, G6 | 0009, 0010 | **New** |
| PR-23 | Usage is metered per fair-use dimension and visible to the customer before an envelope is reached | G8 | 0008 | **New** |

### Phase 4 — the full product surface

Added 2026-08-18 by **ADR-0070 (Accepted)**, which found that three inventories of the web surface
disagreed: the BFF served eighteen routes and ten had a UI, several `PR-#` rows above rendered
nowhere, and the `./UI` prototype showed a larger product than either. PR-24…PR-27 name behaviour
the platform already has and no person can reach. PR-28…PR-32 adopt surfaces the prototype shows;
ADR-0070 records, in its own consequences, that their evidence is a mockup rather than a user, and
that each of the first four is a bounded context under ADR-0022 rather than a screen. **PR-32 was
withdrawn on 2026-08-19** — see §5.1.

**Every row here is bound by ADR-0070's route-before-pixel law:** no UI before the BFF route it
reads, and no route before the backend port it shapes.

| ID | Requirement | G | ADR | Spec / Task |
|---|---|---|---|---|
| PR-24 | A developer can list the repositories they may see, and only those; a repository they may not see is not distinguishable from one that does not exist | G1, G2 | 0070 | **New** |
| PR-25 | A developer can read a file's blame and a ref's commit history in the web UI | — | 0070, 0015 | **New** (PR-8's unbuilt half) |
| PR-26 | A developer can see pipeline runs and job logs for a repository, scoped by the same permissions as the repository read | G1 | 0070, 0005 | **New** (PR-11's browser half) |
| PR-27 | A policy owner can author, version, dry-run and enforce a policy from the web UI, with the deciding version recorded | G4, G6 | 0070, 0006 | **New** (PR-16's authoring half) |
| PR-28 | A team can open, assign, label, discuss and close issues, and link them to merge requests | G4 | 0070 | **New** — needs its own context ADR first |
| PR-29 | A team can cut and publish a release from a tag, with its artifacts and notes | — | 0070 | **New** — needs its own context ADR first |
| PR-30 | A repository owner can read and change repository settings — name, description, visibility, members and archival — each change audited | G2, G5 | 0070 | **New** — needs its own context ADR first |
| PR-31 | An org administrator can read the org's members, roles, runners and audit log from an admin area, without gaining repository read access | G2, G5, G6 | 0070 | **New** — needs its own context ADR first |
| ~~PR-32~~ | ~~An unauthenticated visitor is served a marketing landing page that never leaks tenant existence or content~~ | G1 | 0070, 0078 | **Withdrawn 2026-08-19** — see §5.1 |

### 5.1 Withdrawn requirements

A withdrawn requirement keeps its number. Numbers are never reused here — the same rule
`../tasks/README.md` applies to retired task numbers — so that a citation in an ADR, a commit or a
review still resolves to the thing it meant.

**PR-32 — the marketing landing page. Withdrawn 2026-08-19.**

It was adopted by ADR-0070 from the `./UI` prototype, which ADR-0070 itself recorded as evidence
weaker than a customer. **ADR-0078** then decided how it would have to be built if it were built: a
surface that never receives a session, on a different origin, because the `__Host-` cookie binds to
an origin and that is what makes "never receives a session" a property rather than a promise.

Accepting ADR-0078 established that **there was nothing to move** — `webfrontend`'s root has been
the repository list since T-0055, and no marketing page has ever existed in this product. What
remained was a requirement that could not be started from this repository at all: the super-repo
stores pins only (invariant 25), so a marketing surface cannot live here as a directory, and making
it a submodule needs a repository nobody has created or offered to own.

**A requirement nobody can start reads as planned work.** Leaving PR-32 open would have kept a row
in this table that no roadmap could schedule and no team could pick up, which is worse than closing
it — it misrepresents the plan to everyone who reads it, including us.

**What survives the withdrawal:**

- **ADR-0078 stands and is not edited** (Accepted ADRs are immutable — ADR-0001). Its decisions 1
  and 2 are the standing rule for *any* future marketing surface: separate surface, separate origin,
  never a session. If this requirement returns, it returns under them.
- **Decision 3 is live and enforced.** `webfrontend`'s root stays the repository list, guarded by
  T-0067, which fails if someone puts a splash page there. Withdrawing the requirement removes the
  work, not the risk — the reason someone would add a marketing page to the authenticated app is
  unchanged.

**What would reopen it:** a marketing surface with an owner and a repository. This is not a decision
about whether the product should have a marketing page; it is a statement that this repository is
not where one gets built, and that the PRD should stop implying otherwise.

## 6. Pricing & fair use (product behavior only)

ADR-0008 fixes **flat-rate + fair-use**. This PRD does **not** set prices or tier names — the
unit-economics model is an open ADR-0008 follow-up. It fixes the *dimensions* and the *behavior*:

**Envelope dimensions:** seats · repository count · total repository storage · CI job minutes ·
CI concurrency · scan volume · code-search index size · egress.

**Enforcement — throttle and notify; never block git:**

| Condition | Behavior |
|---|---|
| Approaching an envelope (threshold crossed) | in-product notice + email to the platform engineer; usage view shows the dimension and the trend |
| Envelope exceeded — CI dimensions | job concurrency reduced and queue depth capped; running jobs finish; queued jobs are delayed, never silently dropped |
| Envelope exceeded — storage / index dimensions | growth warned and reported; new large-object writes may be throttled |
| Envelope exceeded — any dimension | **git push, fetch, clone, and all reads remain fully available**; repos are never made read-only for commercial reasons |
| Sustained overage | handled commercially (plan conversation), never by degrading correctness or availability |

Read-only is reserved for the durability failure mode in PR-7 (ADR-0018) and must never be used as
a billing lever. No automatic metered overage billing — that would contradict the flat-rate promise
in ADR-0008 and requires a superseding ADR.

## 7. Non-goals

Explicit, and enforceable as scope boundaries:

1. **Air-gapped installation** (Topology A) — parked in the roadmap; not built, not sold, not
   designed for.
2. **Package/artifact registry beyond container images** — no npm/Maven/PyPI/Go module registry;
   registry hardening beyond containers is out.
3. **Issue tracking / project management** — no issues, boards, sprints, or epics as product
   features. Integration with the customer's existing tracker is the path.
4. **Self-hosting on non-managed Kubernetes** — bare metal, OpenShift, k3s, Docker Compose, and VMs
   are unsupported. ADR-0010 targets GKE/EKS/AKS only.
5. Also out: wiki/pages, chat, self-service force-promote (ADR-0018 keeps it operator-only until
   decided), consumption-metered billing, service extraction without an ADR-0026 trigger.

## 8. Success metrics

**North star:** **findings triaged-to-resolved per week, per active org.** Chosen because it
measures the wedge (PR-13…PR-16), not git parity — a customer can host repos elsewhere and still
buy this.

| Tier | Metric | Why |
|---|---|---|
| North star | findings triaged→resolved / week / org | the wedge is being used, not just installed |
| Activation | days from onboarding to first policy-gated merge | proves PR-10 + PR-16 landed in the customer's flow |
| Retention/habit | weekly active repos with a merged MR | core adoption; guards against a dashboard nobody works in |
| Wedge depth | share of merges where a policy decision was recorded | governance is enforced, not decorative |
| Compliance value | time-to-audit-evidence (hours to produce a dated evidence pack) | the economic buyer's pain (PR-17) |
| Cost governance | share of orgs inside all fair-use envelopes; cost per active repo | flat-rate stays solvent (G8) |
| Trust | accepted-push data-loss events (target: zero) | PR-6/PR-7 are non-negotiable |

## 9. Non-functional targets — mid-market envelope

Per-tenant scale ceiling the product is designed and tested to. Exceeding a ceiling is a cells
conversation (ADR-0003), not a silent degradation.

| Dimension | Target |
|---|---|
| Seats per tenant | ≤ 500 |
| Repositories per tenant | ≤ 5,000 |
| Largest single repository | ≤ 20 GB |
| API / web availability | 99.9% monthly |
| Git clone — time to first byte | p95 < 2 s |
| Accepted-push durability | **RPO = 0** (ADR-0016) |
| Recovery from single git-node loss | RTO < 5 min, automatic |
| Dual loss | fail-safe read-only + audited override (ADR-0018); no RTO promise |
| CI job start latency | p95 < 30 s from trigger, inside envelope |
| Findings freshness | scan results visible on the MR within one pipeline duration |
| Audit trail | append-only, tamper-evident, no delete path (ADR-0007) |

These numbers constrain T-0007 (storage benchmark): the 20 GB repo ceiling and the p95 < 2 s clone
target are the bar the storage decision must clear.

## 10. GA definition

**GA = Phase 3 exit** (`../roadmap/README.md`) **plus** a **SOC 2 Type II** report covering the
hosted control plane and hosted data plane.

At GA all of the following hold: Phases 0–2 exits met; PR-1…PR-19 shipped; BYO (PR-20…PR-22)
installable and operated for at least one production customer; fair-use metering visible (PR-23);
SOC 2 Type II report in hand. Pre-GA customers are design partners on the hosted posture.

Note the deliberate asymmetry: BYO must **exist and be proven** at GA, but the **default sold
posture remains hosted** (§4). BYO is an option, not the onboarding path.

## 11. Governance mapping (G1–G9)

| Objective | Covered by |
|---|---|
| G1 Tenant isolation | PR-1, PR-11, PR-19 |
| G2 Least privilege | PR-2, PR-5, PR-18, PR-19 |
| G3 Supply-chain security | PR-13, PR-14, PR-15 |
| G4 Change governance | PR-9, PR-10, PR-16 |
| G5 Auditability | PR-3, PR-7, PR-17 |
| G6 Compliance frameworks | PR-17 (SOC 2 Type II), PR-18, PR-22 |
| G7 Data residency | PR-20, PR-22 |
| G8 Cost governance | §6, PR-23 |
| G9 Least-privilege footprint | PR-20, PR-21 |

## 12. Open questions, new work, and drift

### 12.1 New work this PRD implies (no task exists today)

| Item | Requirement | Needs |
|---|---|---|
| Repo + MR-history import from GitHub/GitLab | PR-12 | new spec + task(s); Phase-1 scope increase. Audit-integrity question settled by **ADR-0029 (Accepted)** — imported history is `ATTESTED_IMPORT`, never enters the audit log, and imported approvals never satisfy a merge policy. **SPEC-0011 Approved**; delivered by T-0018 (code and history in one unit). |
| Phase-2 requirements PR-13…PR-19 | wedge | backlog epics + specs + tasks; backlog currently says Phase 2 "to be expanded" |
| Phase-3 requirements PR-20…PR-23 | BYO/commercial | backlog epics + specs + tasks; backlog currently says Phase 3 "to be expanded" |
| Fair-use metering & enforcement (§6) | PR-23 | spec + task; resolves the ADR-0008 unit-economics follow-up input side (dimensions + behavior fixed here, prices not) |
| Phase 1/2/3 plan files | — | `../plans/` holds only `phase-0-foundations.md` (itself now current — §12.2 item 4 resolved) |
| Phase-4 requirements PR-24…PR-27 | full product surface | backend ports + BFF routes + web UI, in that order (ADR-0070's ordering law); specs and tasks under EP-26 |
| Phase-4 requirements PR-28…PR-31 | full product surface | **a Proposed ADR each, first** — issues, releases, repository settings and the admin area are bounded contexts under ADR-0022, with their own storage, events, permissions and audit obligations. A screen is not a context. EP-27 |
| ~~PR-32 marketing landing page~~ | — | **Closed 2026-08-19**: the requirement is withdrawn (§5.1). ADR-0078 settled *how* such a surface must be built; what it could not settle is *where*, and nobody owns one. The rule survives the requirement |

### 12.2 Drift to reconcile in governance

Resolved (2026-07-31): `../agents/context.md` product line no longer lists **issues** and now points
here for non-goals; `../tasks/README.md` T-0001 status matches its task file; tasks T-0002…T-0009
carry `Repo(s):` per super-repo `AGENTS.md` rule 2.

Resolved (2026-08-03): `../backlog/README.md` EP-0 listed only T-0001 and T-0002, though T-0008 and
T-0009 both carry `Phase / Epic: 0 / EP-0` in their task files; the epic now lists all four. The
§7 non-goal "service extraction without an ADR-0026 trigger" became mechanically observable with
T-0009's trigger report, whose budgets are set by ADR-0030 (Accepted).

Open:
1. `../plans/` holds only `phase-0-foundations.md` — no Phase-1/2/3 plan files, so EP-8 (T-0018) and
   all Phase-2/3 requirements are sequenced only by task-level `Depends on`.
2. Phase-0 requirements here are PR-1…PR-4, which map to T-0004…T-0007. The enablement tasks — the
   four EP-0 ones (T-0001, T-0002, T-0008, T-0009) and **T-0020** (EP-9, contract schema gate) —
   intentionally have no `PR-#`: they are internal with no customer-visible surface (§5). Noted so
   their absence reads as deliberate rather than as a gap.
3. ~~`../process/ci-gates.md` marks a contract-schema check required in four repos that exists in
   none.~~ **Resolved 2026-08-06** by ADR-0032 + T-0020: `buf lint`/`buf breaking` are required in
   governance and generated-code freshness in the super-repo, and that table's rows were corrected —
   the old four-repo shape was unbuildable, since each consumer's `buf.gen.yaml` reads
   `../governance/contracts`. Per-consumer gating remains open under the ADR-0027/0028
   generated-type publishing follow-up.
4. ~~`../plans/phase-0-foundations.md` lists nine workstreams and predates T-0020.~~ **Resolved
   2026-08-06:** the plan carries T-0020 as workstream 10, notes why it sits out of dependency order,
   and its exit criteria now say which workstream satisfies which half of the CI line. Item 1 (no
   Phase-1/2/3 plan files) is unaffected and still open.

### 12.3 Still-parked human decisions this PRD depends on

- Unit-economics model per tier — ADR-0008 follow-up. §6 is unblocked without it; pricing is not.
- Tenant self-service force-promote — ADR-0018/0016. §7 assumes operator-only until decided.
- Cert issuance/rotation (SPIFFE/SPIRE) + proxy fallback — ADR-0017. Gates PR-20/PR-21.
- Compliance frameworks beyond SOC 2 Type II (ISO 27001, others) — deliberately unnamed; adding one
  changes PR-17's evidence model and belongs in a PRD revision.
- Retention of attested imported records — ADR-0029 says repo retention, not audit retention, but the
  audit retention policy itself is still an ADR-0007 follow-up. Does not block T-0018; must be settled
  before Phase-2 evidence export (PR-17/PR-18) relies on it. Last open item from SPEC-0011.

### 12.4 Assumptions

- "Regulated" means an external audit obligation exists, not a specific framework certification.
- Scanner selection for PR-13 is an implementation choice, not a PRD commitment.
- SOC 2 scope at GA covers hosted planes only; a BYO customer's own cluster is their control
  environment, evidenced via PR-22.
