# Backlog — epics

Epics group tasks by roadmap phase and link down to `../tasks/`. Each task file's own `Status:` is
authoritative; **Definition of Done** for all of them is `../process/definition-of-done.md`.

## Phase 0 — Foundations · all epics CLOSED

| Epic | Tasks | Closed |
|---|---|---|
| **EP-0** Scaffolding & process | T-0001, T-0002, T-0008, T-0009 | 2026-08-04 |
| **EP-1** Platform up | T-0003 | 2026-08-09 |
| **EP-2** Tenancy & governance base | T-0004, T-0005, T-0006 | 2026-08-06 |
| **EP-3** Storage decision | T-0007 | 2026-08-06 |
| **EP-9** Contract gates | T-0020 | 2026-08-06 |

What is worth carrying forward out of them:

- **EP-0** closed when the gates began to *block* rather than only run: ADR-0031 split `main`
  enforcement into two rulesets, verified empirically at the time — a direct admin push to `main` was
  `[remote rejected]`. **ADR-0031 is now superseded by ADR-0053:** the repos went private, and this
  plan gives a private repo neither rulesets nor branch protection (both endpoints answer 403), so that
  mechanism can no longer be applied or verified. Work lands directly on `main` and CI on push is the
  gate.
- **EP-2**: SPEC-0002's open question is answered — decision-cache invalidation is by *bundle
  revision*, not by clock, so a policy change invalidates every cached decision by construction. And
  **AC4's fitness function is a tripwire, not a proof**: authorization logic has no import signature
  the way every other boundary rule does, so it catches the obvious shapes only, and says so. Carried
  out, not blocking: no mTLS between BFF and PDP yet (T-0013).
- **EP-3**: ADR-0033 Accepted — live bare repos stay on block volumes, because SeaweedFS-FUSE's
  `rename()` is not atomic and git renames a `.lock` over the ref on every update (36 of 428 concurrent
  ref reads missed a ref that always existed; 0 of 229 on block; zero rename errors, reproduced three
  times). Performance was not the deciding factor. ADR-0016 needed no amendment and invariant 7's
  escape clause is discharged. Evidence: `../bench/T-0007/`.
- **EP-9**: T-0020's AC5 was **amended** during implementation — per-consumer codegen gating is
  impossible while each `buf.gen.yaml` reads `../governance/contracts`, so freshness is gated at the
  composition boundary instead. The per-repo variant stays blocked on the ADR-0027/0028 generated-type
  publishing follow-up.

## Phase 1 — MVP · all epics CLOSED

| Epic | Tasks | Landed |
|---|---|---|
| **EP-4** Git plane | T-0010, T-0011, T-0012 | backend #20, #27/#28, #30 |
| **EP-5** Identity | T-0013 | backend #21/#37/#50, bff #22, governance #124 |
| **EP-6** Code UX | T-0014, T-0015 | backend #22/#24, bff #18/#22, webfrontend #20, super-repo #77 |
| **EP-7** Review & CI | T-0016, T-0017 | backend #29/#31/#32/#33/#34/#35, super-repo #76 |
| **EP-8** Migration | T-0018 | governance #110/#114/#116, backend #39/#40/#45/#46, bff #25, webfrontend #23 |
| **EP-10** Deployable images | T-0021 | backend #19/#25, bff #16/#19, webfrontend #16/#18 |

Two limits are recorded against the phase rather than left open (see `../plans/phase-1-mvp.md`): no
gVisor RuntimeClass under rootless podman, so CI dispatch is unconfigured in the dev cluster (T-0017),
and one git node, so the durability quorum and failover cannot be demonstrated there (T-0012/T-0018
prove both in their suites).

**EP-8 owes one criterion forward.** T-0018's **AC19 moved to Phase 2** (decided 2026-08-10): an
evidence pack spanning an import must carry zero attested records in its control sections, with
attested history confined to a labelled appendix carrying its provenance blocks and the admitting
`HistoryImported` event (SPEC-0011 AC14). No evidence-pack surface exists yet to satisfy it. **ADR-0029
§4 binds whoever builds that surface whether or not the criterion is copied into their task.** It is
now owned by **EP-13 / T-0026 (AC2)**, which carries the criterion verbatim.

## Phase 2 — Ultimate wedge · all epics CLOSED

Plan: `../plans/phase-2-ultimate-wedge.md` (Active 2026-08-14; exited 2026-08-14). Scope was exactly
PR-13…PR-19.

| Epic | Tasks | Landed |
|---|---|---|
| **EP-11** Findings plane | T-0022, T-0023, T-0024 | contracts governance@8b4dac2/bcd37c9/6fa2a24; backend acb4a9c→c64e6a3; bff d290e14/47360c2; webfrontend 5b53c36+92804eb |
| **EP-12** Policy-as-code | T-0025 | contracts governance@e412eb4; backend 67b0224 + e475683; super-repo composition harness (merge-gate ALLOW/DENY pair) |
| **EP-13** Evidence & auditor access | T-0026, T-0027 | contracts governance@178d97a/a9a5c9b; backend 9cfd392 + 50bdc34/6e4696c; bff 3c4ebe0/77fac5e |
| **EP-14** Code search | T-0028 | contracts governance@011eb2a; backend 267eaa4 (merged into the stack tip at 6b66da4 for the single super-repo pointer); bff 4b93d25 |

Super-repo exit pins (task #23, 2026-08-14): backend **6b66da4**, bff **b7c3763**, webfrontend
**7997c7c**, governance at the exit status-docs commit atop 450cded.

**EP-8's owed-forward criterion is discharged.** T-0018 AC19 — a pack spanning an import carries zero
attested records in its control sections — shipped verbatim as T-0026 AC2 and was proven live
(TestLiveEvidencePackProof at the exit pins).

Two classes of limits are recorded against the phase rather than left open (see
`../plans/phase-2-ultimate-wedge.md` exit verdict): the **gVisor/host-bound steps** — CI-dispatched
scan on an MR, measured scan freshness (T-0024 AC4) and measured index freshness (T-0028 AC4) — sit
against T-0003's cluster lane exactly as Phase 1 recorded them; and the exit e2e scenario's
live-cluster steps were demonstrable only up to the host limit (dev-cluster bring-up blocked at the
interactive mkcert/ingress step on this host). The Phase-2 code review added a third class —
**deployment-posture limits** (unauthenticated dataplane door, in-process-only restart state) —
recorded in the carried-forward list below and in the specs they bound. The review's remaining 15
findings (H1, H3–H6, M7–M12, L14–L17) were code fixes merged to backend main at **42ad9b3** (fix
wave 2 — see the exit plan's fix-wave block); two of them carry governance follow-ups below.

Carried forward out of Phase 2:

- **`/api/v1` route-prefix deviation.** Every Phase-2 BFF surface shipped under `/api/v1` (as filed in
  T-0023…T-0027), while Phase-1 surfaces use bare `/v1`. Both are live and tenant-scoped; unifying
  them is a routing-hygiene item for a future task, not a correctness gap.
- **Repo-scoped security dashboard folded into the unified surface.** Stage 1 of the plan named two
  dashboard routes — org-wide `/security` and repo-scoped `/repos/[repositoryID]/security` — but only
  the unified `/security` page shipped, with repo scope served as a `?repository=` filter per
  ADR-0015's unified-surface direction (webfrontend 5b53c36, asserted in T-0023's exit record). The
  second route was never built; record the substitution here since it was not itemized at exit.
- **bff `gen/proto/policy/v1` was regenerated at exit** (bff@b7c3763, webfrontend@7997c7c) because
  the super-repo `codegen-check` gate hard-fails on drift — the pinned BFF work itself consumes only
  `Decide`, so the T-0025 EvaluateDryRun/provenance surfaces have no BFF consumer yet; their first
  consumer lands with whatever task needs dry-run in product.
- T-0003's **cluster lane** remains the standing owner for the infrastructure-bound demonstrations
  (gVisor RuntimeClass under rootless podman, multi-node durability, measured freshness bounds). Its
  Phase-2 carried set, in order: first the **`CIJobFinished`→ingest wiring — DONE** (backend@49d6bfa,
  closed by **T-0029** / SPEC-0037 / ADR-0059: the runner persists the report and a Security
  subscriber ingests it off `CIJobFinished`), so the event-driven path the freshness measurements
  observe now exists. Everything below still waits on the cluster: **CI-dispatched scans** (gVisor),
  then the measured demonstrations — **T-0024 AC4 measured findings freshness** and **T-0028 AC4
  measured index freshness** — and the **exit-scenario live-cluster walk** the dev host could not
  host.
- **Dataplane door auth posture (code-review H2).** The dataplane gRPC door
  (`backend/cmd/dataplane-app/gitfront.go`) is unauthenticated — no transport credentials, no auth
  interceptor, no tenant-pinning interceptor — and the Phase-2 services on it take tenant/actor/roles
  from the request body, so security rests on network isolation of the port plus the single-tenant dev
  posture. Phase 1's `Decide` had the same posture by PDP-call nature; Phase 2 widened the surface.
  Recorded as a deployment-posture limit (SPEC-0002's open questions, exit plan note (d)). Follow-up:
  door authentication + server-derived tenant-pinning interceptor before any posture that does not
  isolate the port.
- **In-process Phase-2 state (code-review M13).** The attribution MR projection + materialized
  comparisons, the evidence-pack assembly state + idempotency reservations, and the code-search index
  are in-process only — none survives a dataplane restart, and the index has per-repo bounds but no
  per-tenant or global cap. Recorded as limits against SPEC-0031 AC8 and SPEC-0034 AC4/AC5, holding
  under the single-tenant dev posture with restart re-announcement as the recovery path. Follow-up:
  startup seeding or persistent stores for packs, the projection and the index; per-tenant index caps.
- **PDP-driven merge-gate severity threshold (code-review M11).** Fix wave 2 (backend@42ad9b3)
  enforced the threshold as a rego-vs-Go parity test in backend CI, but SPEC-0029 AC3 wants the rule
  in the bundle: the assembler should pass the severity distribution and the triage records to the
  PDP and let the rule pick the threshold, removing the mirrored Go constant. Follow-up: governance
  contract change to the security merge-gate facts (additive, governance PR first per ADR-0027),
  then backend moves the threshold filtering into the PDP.
- **Attribution UNAVAILABLE reason wire enum (code-review L14).** Fix wave 2 (backend@42ad9b3) makes
  the attribution carry the resolver-not-composed reason internally, but the wire contract has no
  enum value for it, so gRPC renders it `UNSPECIFIED` until contracts add one (SPEC-0028 AC7 names
  the reason). Follow-up: additive contract change adding the value, then the backend surfaces it.

**EP-11 gates the phase.** T-0022 fixes the normalized findings model and, harder, the rule for
**stable finding identity across scans**; triage that survives a re-scan (T-0023), MR attribution
(T-0024) and the scan-gate sections of an evidence pack (T-0026) all degrade at once if it is wrong.
Nothing outside EP-14 should start before T-0022's contract is merged in `governance/`.

**EP-13 owns the criterion EP-8 owed forward.** T-0018's AC19 is carried verbatim as **T-0026 AC2**.
Its gate is closed: **ADR-0055 (Accepted 2026-08-14)** settles audit retention — the chain never
removes anything, attested imported records live outside the chain and expire a year after import or
with their repository, and an evidence pack is a self-contained snapshot. SPEC-0031/0032/0033 are
Approved and both tasks may go RED.

**EP-14 is independent** and gates nothing; it can run alongside EP-11 from the start.

**All twelve specs Approved 2026-08-14** — SPEC-0024…SPEC-0035. Every Phase-2 epic may go RED.
Next free: SPEC-0036.

Three decisions were taken at approval and are recorded in the specs themselves:

- **SPEC-0029's authoring fork — reading A.** Policy stays reviewed Rego in `governance/policies`;
  git is the version store and the recorded policy version is the bundle revision. Reading B
  (in-product per-tenant authoring) would be a second mutable policy source and requires a Proposed
  ADR before any contract work.
- **Proto package paths** — `contracts/proto/security/v1` for findings (ADR-0022's context name),
  `search/v1` for code search, and a new `audit/v1` for Audit's first RPC surface.
- **Audit retention — ADR-0055 (Accepted 2026-08-14).** The append-only chain never removes anything
  (tenant-lifetime retention, ADR-0007 invariant 5 unqualified, no tombstones); attested imported
  records sit outside the chain per ADR-0029 and expire one year after import or with their
  repository, while the admitting `HistoryImported` event is chained and outlives them; an evidence
  pack is a self-contained snapshot; neither period is tenant-configurable in v1. This closes
  ADR-0007's retention follow-up and SPEC-0011's last open item.

## Phase 3 — BYO & commercial *(implementation complete 2026-08-15; cluster-lane proof pending)*

Plan: `../plans/phase-3-byo.md`. Scope is PR-20…PR-23. The architecture was already decided
(ADR-0009/0010/0011/0013/0017); the two open decisions are settled by **ADR-0060** (enrolment token
plus control-plane-issued certificates) and **ADR-0061** (the control plane is the metering
authority).

| Epic | Requirement | Tasks | Specs | State |
|---|---|---|---|---|
| **EP-15** BYO data plane | PR-20 | T-0030 | SPEC-0038 | Done — AC1–AC9 proven |
| **EP-16** Packaging & lifecycle | PR-20, PR-21 | T-0031, T-0032 | SPEC-0039 | Done — AC1–AC7 proven; AC8 real-state proof carried |
| **EP-17** Residency & evidence | PR-22 | T-0033 | SPEC-0040 | Done — AC1–AC8 proven |
| **EP-18** Commercial | PR-23 | T-0034 | SPEC-0041 | Done — AC1–AC10 proven |

All five tasks are **Done** (exit records in `../tasks/`): T-0030 contracts governance@5e33e90 +
authz governance@2c268d3, backend@8e5d013; T-0031 backend@4b26cb2, super-repo@150cc2b; T-0032
governance@dea5476, backend@85b773c, super-repo@149b3e2; T-0033 governance@0e61302, backend@c630a1e;
T-0034 governance@5dff9b3, backend@d3f4ad6, bff@e2344de, webfrontend@95f77be+0e80261.

**What is proven and what is carried.** Every task-level acceptance criterion is proven by named tests
at the exit pins; the phase's final exit criterion — the whole path proven once end to end on a real
customer-shaped cluster, not a harness — is **not** among them and is carried to T-0003's cluster
lane. The conformance-matrix rows exist and are all marked real-cluster "not run" — honest by
construction. Recorded the same way Phase 1/2 recorded their host limits, as carried proof rather than
open code.

Carried forward out of Phase 3 (in addition to the cluster-lane proof above); items the Phase 3.1
epics now own are annotated with their new epic — the mapping is restated in §Phase 3.1 below:

- **Real-cluster conformance proof.** The whole install → self-register → upgrade → meter path on a
  real customer-shaped cluster (GKE/EKS/AKS), plus SPEC-0039 AC8's forward/backward migration proof on
  real state. Owned by T-0003's cluster lane. → executed by **EP-22** (T-0041 harness half, T-0042
  real half — still blocked-by the lane).
- **Proxy-only egress** (ADR-0017's remaining follow-up) — still open, still able to block an install
  outright for a customer whose egress permits only an HTTP proxy (tracked already; unchanged).
- **CA key custody** (ADR-0057-scoped platform-secrets follow-up) — the enrolment CA runs on dev key
  custody; production custody is the platform-secrets decision SPEC-0038's out-of-scope names.
  → **EP-21** (T-0040). **Closed 2026-08-15** — EP-21 complete: T-0040 is Done — the production
  composition root signs through the deployed, pinned OpenBao custody service exclusively, and
  rotation distributes as a staged CA trust bundle over reconcile (backend@b0ab32e +
  super-repo@f8449b8; Wave-3 close-out at backend@28f729f + super-repo@5adedf1).
- **Postgres adapters for the agent/residency in-memory stores** — the enrolment-token/data-plane
  registry and the residency declaration store do not survive a control-plane restart; the audit trail
  is durable, the live stores are not. → **EP-19** (T-0036, T-0037). **Closed 2026-08-15** — EP-19
  complete: T-0036 (agent stores) and T-0037 (residency declarations + pack assembly) are Done, and
  T-0037's exit record closes T-0033's recorded in-memory-store limit.
- **Residency Declare wire surface** — the declaration is set by in-process composition only; a
  wire/RPC surface is future work. → **EP-20** (T-0038, with placement hardening in T-0039).
  **Closed 2026-08-15** — EP-20 complete: T-0038 (governance half at 794f578/3b9e853, bundle
  0.10.0, + backend half) and T-0039 are Done at backend@f182761, closing T-0033's recorded
  Declare-wire limit.
- **PR-7 read-only enforcement** — the commercial read-only prohibition holds now, but the in-product
  distinction from the PR-7 durability read-only mode (ADR-0018) is enforced per ADR-0061 when PR-7
  ships. → **EP-23** (T-0044). **Closed 2026-08-16** — T-0044 is Done (backend@0238dee +
  webfrontend@843a195): every read-only state names its cause and commercial states never render
  read-only; EP-23 complete with T-0043.

Open and able to block a sale rather than a sprint: **proxy-only egress** (ADR-0017's remaining
follow-up) stops an install outright for a customer whose egress permits only an HTTP proxy.

## Phase 3.1 — North Star *(planned 2026-08-15)*

Plan: `../plans/phase-3-byo-v2.md` (accepted 2026-08-15, amended 2026-08-15). Turns Phase 3's carried
set into production posture under **ADR-0062…ADR-0067** (Accepted) and **SPEC-0042…SPEC-0046**
(Approved), all 2026-08-15.

| Epic | Requirement | Tasks | Specs | State |
|---|---|---|---|---|
| **EP-19** Durable control-plane stores | PR-20, PR-22 | T-0036, T-0037 | SPEC-0042 | Done — AC1–AC6 proven real-Postgres (T-0036 backend@c9e58c5, T-0037 backend@816cb30) |
| **EP-20** Residency Declare & placement hardening | PR-22 | T-0038, T-0039 | SPEC-0043 | Done — T-0038 governance half at 794f578/3b9e853 (bundle 0.10.0) + backend half at backend@f182761; T-0039 at backend@f182761; closes T-0033's Declare-wire limit |
| **EP-21** Agent-CA custody & rotation | PR-20 | T-0040 | SPEC-0044 | Done — T-0040 AC1–AC5 proven at backend@b0ab32e (composition swap, reconcile distribution, fitness) + super-repo@f8449b8 (runbook §6b, wiring assertions) on the super-repo@31c9b45 deployment; live dev-OpenBao issuance round-trip proven, honest "not run" rows recorded; Wave-3 review close-out at backend@28f729f + super-repo@5adedf1 |
| **EP-22** Multi-cluster BYO readiness | PR-20, PR-21 | T-0041, T-0042 | SPEC-0045 | In progress — T-0041 Done (SPEC-0045 AC1, AC2 harness half, AC4, AC5 proven at backend@762d5f0 + a669cef, super-repo@febf0f7 on governance@b5128b0); T-0042 carries AC3 + AC2's real-cluster half, blocked by T-0003's cluster lane |
| **EP-23** Usage-view truth & PR-7 distinction | PR-23, PR-7 | T-0043, T-0044 | SPEC-0046 | Done — T-0043 AC1/AC2/AC3/AC5 proven (backend@bc30abd, bff@4059a23, webfrontend@08f42c4; contracts governance@b425db0/36f284b); T-0044 AC4/AC5 proven (backend@0238dee, webfrontend@843a195) |

**T-0036 is Done** (exit record in `../tasks/T-0036-durable-agent-stores.md`): backend@c9e58c5,
2026-08-15 — the durable enrolment-token store and data-plane registry proven against a real-Postgres
harness with zero skips (AC1 spend/revocation durability, AC2 staleness recomputation, AC5 agent
migrations/RLS/hash-only persistence, AC6 release-the-claim on issuance failure — the user-approved
interim posture a Phase 3.2 candidate ADR-0068 now explores superseding). Super-repo pin bump at
super-repo@c7904d1 with the agent migration wired into `dev-provision.sh`. Carried: CI skips the
durability proofs without `TEST_DATABASE_URL`, and the AC6 runbook edit rides T-0040's super-repo
commit. The governance pin bump waits for Wave 3a — consumers must regenerate and commit the
residency codegen first (freshness is gated at the super-repo pin, T-0020 AC5).

**T-0037 is Done — EP-19 is complete** (exit record in `../tasks/T-0037-durable-residency-pack-assembly.md`):
backend@816cb30, 2026-08-15 — the durable residency declaration store (effective-dated rows with
retained history) and evidence-pack assembly from durable projections only, proven with `-race`
against a real-Postgres harness with zero skips (AC3 durability/effective-dating with an identical
pack digest across kill −9/restart, AC4's import-closure fitness gate against in-process stores,
AC5 residency migrations/RLS/no-unscoped-path). It **closes T-0033's carried limit** — *the
declaration store is in-memory and lost on a control-plane restart* — the last in-memory store Phase
3 recorded. Carried, verbatim from T-0036: CI skips the durability proofs without
`TEST_DATABASE_URL`. The super-repo governance pin bump still waits for Wave 3a (consumer residency
codegen first, T-0020 AC5).

**T-0038 and T-0039 are Done — EP-20 is complete** (exit records in
`../tasks/T-0038-residency-declare-surface.md` and `../tasks/T-0039-placementgate-hardening.md`):
backend@f182761, 2026-08-15, governance half at 794f578/3b9e853 (bundle 0.10.0) — the residency/v1
Declare door (verified caller before the PDP, coarse refusals, one audit record per act, the
agent-channel tripwire, the tenant-scoped `platform_operator` grant) and the PlacementGate
hardening (contradiction and silence rendered in pack and findings with the existing vocabulary,
gate refusal that never spends the token and fails closed on an unavailable store). They **close
T-0033's carried limit** — *Declare has no wire/RPC surface in Phase 3*. Carried, verbatim from
T-0036/T-0037: CI skips the durability proofs without `TEST_DATABASE_URL`.

**T-0040 is Done — EP-21 is complete** (exit record in
`../tasks/T-0040-agent-ca-custody-rotation.md`): backend@b0ab32e + super-repo@f8449b8, 2026-08-15
— the production composition root composes the custody-backed issuer exclusively (AC1/AC3
fitness-asserted), CA rotation distributes over reconcile as `DesiredState.ca_trust_bundle` on the
staging epoch (AC2), MVP-RUNBOOK §6b covers rotation, unseal, outage, the SPEC-0042 AC6
enrolment-mid-flight case (claim released, retry re-binds the same `data_plane_id`) and the
clock-skew cross-reference (AC4), and the custody service stays deployed, pinned and check-
asserted incl. the new wired-consumer assertion (AC5). ONE live issuance round-trip ran against the
dev OpenBao through the shipped composition (Kubernetes-auth login, non-exportable transit key);
throwaway keys deleted. Recorded "not run": no rotation against a real fleet, and the
custody-enabled control-plane image is not yet built or deployed. Shared mechanism named per the
task's ordering Note: T-0041's release trust bundle rides the same DesiredState channel as a
separate field; naming and tests stay strictly apart.

**EP-21's carry (SPEC-0041 AC5's shape, board #20 close-out):** `DesiredState.ca_trust_bundle` is
DISTRIBUTED over the reconcile channel — both roots ride it during the dual-validate window — but
NO data-plane consumer applies it yet; the application half rides with the operator/multi-cluster
work and its owners are named: **T-0041/T-0042**. Beside it, two named follow-ups from the same
close-out: runtime rotation actuation (`Bundle.Stage`/`Bundle.RemoveRoot` have no production
caller in the shipped binary — distribution, the window, and removal-precondition enforcement when
removal is invoked are what execute today) and the custody-enabled image's deployment requirement
for a persistent volume under `GITFROK_CUSTODY_SNAPSHOT_FILE` (deploy/dev/controlplane.yaml has no
PVC today — an honest carry, not added now). Both are recorded in T-0040's exit record and in
MVP-RUNBOOK §6b, which states the snapshot-file semantics (Restore/Bootstrap/re-attach, atomic
0600 writes, corrupt snapshot fails startup loudly) against backend@28f729f. The Wave-3 review fix
chain (7d5b693, 212e17d, 19af0ed, eb2ed15, 28f729f) landed verified-green at backend@28f729f and
the super-repo pins were bumped to it at super-repo@5adedf1.

One line each (detail in the plan and the specs):

- **EP-19** — Postgres adapters behind the existing ports (enrolment-token store, data-plane registry,
  residency declarations), additive module-owned migrations, RLS everywhere, effective-dated
  declarations, pack assembly from durable projections only (ADR-0062).
- **EP-20** — an additive `residency/v1` admin gRPC surface where the caller is verified (ADR-0045),
  the PDP decides and every act is audited, plus placement contradiction/gap hardening and the
  agent-channel tripwire (ADR-0063). A tenant-scoped platform operator may declare on a tenant's
  behalf beside the owner grant — **ADR-0067** (Accepted), carried as SPEC-0043 AC7 with its policy
  change in T-0038.
- **EP-21** — the agent CA signs through platform-secrets/KMS custody and rotates by a staged **CA
  trust bundle** with a dual-validate window, no fleet re-enrolment; the dev CA is test-only
  (ADR-0064); the custody service itself is OpenBao, deployed control-plane-side, unsealed by quorum
  and pinned per ADR-0034 (ADR-0066, SPEC-0044 AC5).
- **EP-22** — a vendor-signed, digest-pinned operator image and **release trust bundle** distribution
  across N data planes per tenant, proven on real GKE/EKS/AKS (ADR-0065). Distinct artifact from
  EP-21's CA trust bundle.
- **EP-23** — divergence health gates with both numbers shown, envelope-state telemetry to the
  browser, and the PR-7 read-only distinction, with never-zero/never-blocked regression pins
  (ADR-0061/0018).

**The Phase 3 carried list above is reclassified, not duplicated** — each annotated bullet now points
at its owning epic; the mapping in full: Postgres adapters → **EP-19**; residency Declare wire
surface → **EP-20**; CA key custody → **EP-21**; real-cluster conformance proof (with SPEC-0039 AC8)
and the operator image → **EP-22**; PR-7 read-only distinction → **EP-23**. The envelope throttle's
data-plane half stays **T-0035** — opened by the 2026-08-15 review before this phase was planned, on
EP-18's books, and gating T-0043. **Proxy-only egress is unchanged** (ADR-0017's remaining follow-up,
able to block an install outright). Closed by the review and carried nowhere: the CA trust-ordering
fix (backend@e722046) and the derived no-inbound fitness tree — neither is open here.

## Phase 3.5 — the design system *(complete 2026-08-17)*

Plan: `../plans/phase-3-5-design-system.md`.

| Epic | Requirement | Tasks | Specs | State |
|---|---|---|---|---|
| **EP-24** CVD-first design system | PR-8, PR-14, PR-17, PR-18, PR-23 | T-0045, T-0046, T-0047, T-0048 | SPEC-0047 | Done — all ten ACs proven; `webfrontend` only (T-0045 cdf032c, T-0046 089c514, T-0047 0f0dabd, T-0048 56c91d1, captures ad075f4) |

## Phase 4 — the full product surface *(planned 2026-08-18)*

Plan: `../plans/phase-4-full-product-surface.md`. Decided by **ADR-0070** (Proposed).

| Epic | Requirement | Tasks | Specs | State |
|---|---|---|---|---|
| **EP-25** Tier A — the routes that exist and have no UI | PR-9, PR-10, PR-17, PR-18, PR-19 | T-0049, T-0050, T-0051, T-0052 | SPEC-0048…SPEC-0051 | In progress — T-0049 Done (webfrontend@6d61827, SPEC-0048 AC1–AC11); T-0050…T-0052 not yet specced |
| **EP-26** Tier B — the PRD requires it, no route serves it | PR-8, PR-11, PR-16, PR-24…PR-27 | — | — | Not started — each item is backend-first under the route-before-pixel law; no task may open before its backend port exists |
| **EP-27** Tier C — the prototype shows it, nothing requires it | PR-28…PR-32 (all proposed) | — | — | Blocked — ADR-0070 must be Accepted and the PRD amended first; each of issues, releases, settings and admin is a bounded context under ADR-0022 needing its own Proposed ADR |

One line each:

- **EP-25** — merge-request open/review/merge (the write half of PR-9, form-encoded and served since
  T-0016 but never called), permission-filtered code search (`CommandPalette.tsx` is navigation, not
  search — nothing has ever called the search API), evidence-pack request/status/fetch, and auditor
  grant issue/list/revoke. `webfrontend` only; no contract change.
- **EP-26** — repository list first, because without it there is no honest landing page and
  `index.astro` stays the T-0001 stub; then blame and history (PR-8's unbuilt half), pipelines and
  job logs, and the policy authoring surface PR-16 requires.
- **EP-27** — adopted from a mockup rather than a customer, which ADR-0070 records as the risk it is
  most likely to be wrong about. The gate is deliberate: someone must defend PR-28…PR-32 on their
  merits at ADR acceptance, not on the prototype's existence.

## Parked — needs a human decision first

Force-promote tenant self-service (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017) ·
unit-economics model per tier (ADR-0008) · event catalog (ADR-0022 — the boundary linter shipped in
T-0002/T-0009; the names exist as protobuf full names, nothing documents them).
