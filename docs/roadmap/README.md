# Roadmap

Milestone-based; each phase has an **exit criterion** before the next begins. Execution detail is in
`../plans/`, work items in `../backlog/` and `../tasks/`.

## Phase 0 — Foundations · **Complete (2026-08-09)**

Scaffolding, dev environment, tenancy + RLS, PDP, audit log, and the storage benchmark that unblocked
the git-storage design.

**Exit (met):** an empty-but-wired foundation — Minikube with real TLS; tenant-scoping, deny-by-default
policy and append-only audit seams; the storage decision (ADR-0033); boundary, architecture, contract,
policy/isolation and fitness gates enforced in CI.

## Phase 1 — MVP (GitHub-lite) · **Complete (2026-08-11)**

Git push/pull (RPC + sync-replica write path), auth (Zitadel), repo/file/diff UI, MR review with
protected branches, CI v0 (gVisor sandboxes), and the container images that make any of it deployable.

**Exit (met):** a team can host a repo, open/review/merge an MR, and run a pipeline. Tasks T-0010–T-0018
and T-0021 all Done; the code-driven half of the end-to-end scenario executed live 2026-08-11.

Two of the scenario's steps are *demonstrable* only on T-0003's cluster lane, recorded as host limits
rather than open code: CI dispatch needs a gVisor RuntimeClass no rootless-podman driver provides
(T-0017), and the durability-quorum/failover demonstration needs a second physical node (T-0012 and
T-0018 both prove it in their suites). Detail: `../plans/phase-1-mvp.md`.

## Phase 2 — the Ultimate wedge · **Complete (2026-08-14)**

Security scanners → normalized findings → **unified dashboard**; security/approval policies as code;
audit trail + evidence pack export under scoped auditor grants; permission-filtered code search.

**Exit (met):** the differentiating governance/security surface runs end to end. Every scenario step
was executed against live scanners, the real BFF → PDP → Rego path, and live pack/grant proofs — the
evidence mapping is in `../plans/phase-2-ultimate-wedge.md`. Epics **EP-11…EP-14** closed; tasks
**T-0022…T-0028** all Done against **SPEC-0024…SPEC-0035**; **ADR-0055** (Accepted) settled audit
retention, closing ADR-0007's follow-up and SPEC-0011's last open item. T-0018's AC19 — an evidence
pack carries zero attested records in its control sections (ADR-0029 §4, SPEC-0011 AC14) — was
carried verbatim as T-0026 AC2 and proven live.

Three review waves followed the exit and are recorded in the plan: seventeen findings (H1–L17), then
seven on the fixes themselves (N1–N7), then the two residuals. The code that came out of them is
pinned at backend `90bf1a1` / super-repo `086c965`.

**Two deployment-posture limits are carried, not closed** — both recorded in the plan with
follow-ups, and both bounded by the single-tenant dev posture the phase ships under:

- **(d) the dataplane gRPC door is unauthenticated**, so every Phase-2 RPC takes tenant, actor and
  roles off the wire and the PDP decides correctly about a caller-asserted subject. Security rests on
  network isolation of that port plus RLS as the backstop. H1's tenant guard on the decision-record
  reads is implemented and tested but degenerates to a consistency check until a tenant-pinning
  interceptor gives it a verified caller. Recorded in SPEC-0002's open questions.
- **(e) Phase-2 in-process state does not survive a restart** — the attribution projection, pack
  assembly state and the code-search index — and the index has no per-tenant or global cap. Recorded
  against SPEC-0031 AC8 and SPEC-0034 AC4/AC5.

Also carried: the PDP-driven merge-gate severity threshold and the two new gap-reason wire enums,
both additive contract changes tracked in `../backlog/`.

## Phase 3 — BYO · **Implementation complete (2026-08-15) — cluster-lane proof pending**

Agent (implements `contracts/proto/agent/v1`), Operator + Helm, per-cloud drivers, usage metering →
billing + fair-use.
**Exit:** a customer runs the data plane in their own GKE/EKS/AKS under a flat plan.

**Exit (met in code; the real-cluster demonstration is carried, not closed):** tasks **T-0030…T-0034**
all Done against **SPEC-0038…SPEC-0041** — enrolment, self-registration and cert rotation (SPEC-0038
AC1–AC9), the chart, driver seam and signed reconcile upgrades (SPEC-0039 AC1–AC7), residency pinning
and its evidence-pack section (SPEC-0040 AC1–AC8), and fair-use metering with the usage view
(SPEC-0041 AC1–AC10), each proven by named tests at the exit pins. The one exit criterion the harness
cannot satisfy — *the whole path proven once end to end on a real customer-shaped cluster, not a
harness* — is recorded the way Phase 1 and 2 recorded their host limits: carried to T-0003's cluster
lane, with the conformance-matrix rows in place and all marked real-cluster "not run", rather than
counted as met. Carried with it: SPEC-0039 AC8's forward/backward migration proof on real state, the
in-memory agent/residency stores (Postgres adapters), the enrolment CA's production key custody, and
the residency Declare wire surface — all in `../backlog/`, since reclassified into Phase 3.1's
**EP-19…EP-23** (next section).

Plan: `../plans/phase-3-byo.md`. Scope PR-20…PR-23 as epics **EP-15…EP-18**, tasks **T-0030…T-0034**,
specs **SPEC-0038…SPEC-0041** (Approved 2026-08-14; all four Implemented by 2026-08-15). The architecture was decided in
Phase 0/1 (ADR-0009/0010/0011/0013/0017); the two decisions that were open are settled by **ADR-0060**
(one-time enrolment token, control-plane-issued short-lived certificates — closing ADR-0017's
cert-issuance follow-up) and **ADR-0061** (the control plane is the metering authority; a customer's
cluster never reports the number it is measured against).

**Still open, and able to block an install outright:** proxy-only egress — the remaining half of
ADR-0017's follow-up. A customer whose egress permits only an HTTP proxy cannot install today.

## Phase 3.1 — North Star: durability, custody, multi-cluster, commercial maturity · **Implementation complete (2026-08-16) — cluster-lane proof pending**

Plan accepted: `../plans/phase-3-byo-v2.md`. Specs **SPEC-0042…SPEC-0046** Approved (four of the five now Implemented — see the status note below) and ADRs
**ADR-0062…ADR-0067** Accepted (both 2026-08-15), so every epic may go RED. Plan and specs amended
2026-08-15 after the plan review: ADR-0066's OpenBao custody service is deployed under EP-21
(SPEC-0044 AC5), the Declare surface verifies its caller rather than inheriting SPEC-0002's limit (d)
(SPEC-0043 AC6), and a signing failure may not silently burn an enrolment token (SPEC-0042 AC6). One
question the plan had been assuming is now decided rather than inherited: **ADR-0067** (Accepted
2026-08-15) lets a tenant-scoped platform operator declare a tenant's residency beside the unchanged
owner grant, with no cross-tenant path (SPEC-0043 AC7).

Phase 3's recorded limits become production posture: durable control-plane stores behind the existing ports (Postgres adapters,
RLS, effective-dated declarations, pack assembly from durable projections), residency's operator
handle on a PDP-decided `residency/v1` wire surface, agent-CA keys in platform-secrets/KMS custody
with staged trust-bundle rotation, the operator as a signed digest-pinned first-party image across N
data planes, the conformance matrix answered on real clusters, honest divergence health gates through
to the browser, and the PR-7 read-only distinction surfaced. Epics **EP-19…EP-23**, tasks
**T-0036…T-0044**, milestones M1–M4 per the plan's dependency spine.

**Exit:** every SPEC-0042…0046 acceptance criterion green — including at least one real cluster per
cloud or an honestly annotated subset — durable-store restart proofs, custody off-disk proofs,
divergence gates shipped through webfrontend, the full gate matrix green at the final pin bump, and
the runbook current.

**Status (2026-08-19):** SPEC-0042, SPEC-0043, SPEC-0044 and SPEC-0046 are **Implemented**; eight of
the phase's nine tasks are Done. **SPEC-0045 remains Approved** because **T-0042** — the real-cluster
conformance proof on GKE, EKS and AKS — is blocked by the T-0003 cluster lane and is the one piece of
this phase nobody can close from a laptop. EP-22 is therefore the only epic in the backlog still In
progress. The phrasing matches Phase 3's: implementation complete, cluster proof pending, and neither
half pretending to be the other.

**Phase 3 carries, reclassified (history preserved above and in `../backlog/`):**

- Postgres adapters for the agent/residency in-memory stores → **EP-19** (T-0036, T-0037).
- Residency Declare wire surface → **EP-20** (T-0038, with placement hardening in T-0039).
- CA key custody → **EP-21** (T-0040).
- Cluster-lane proof (incl. SPEC-0039 AC8) + signed operator image → **EP-22** (T-0041, T-0042 —
  T-0042 still blocked-by T-0003's lane).
- PR-7 read-only distinction → **EP-23** (T-0044, with usage-view truth in T-0043).
- Envelope-throttle data-plane half → **T-0035** — already open on EP-18's books, filed by the
  2026-08-15 review *before* this phase was planned, and gating T-0043; not renumbered.
- **Proxy-only egress stays open** on its own track (ADR-0017's remaining follow-up) — unchanged by
  this phase and still able to block an install outright.

## Phase 3.5 — the design system · **Complete (2026-08-17)**

Plan: `../plans/phase-3-5-design-system.md`. **ADR-0069** (Accepted) adopts `gitfrok-brand-identity-v2`
and makes its three CVD laws binding; **SPEC-0047** says what "adopted" means in testable terms.
Tasks **T-0045…T-0048**, epic **EP-24**, `webfrontend` only.

**Exit (met):** all ten SPEC-0047 criteria green. Every colour resolves from `src/styles/tokens.css`,
`scripts/check-hex-literals.mjs` fails the build on a literal anywhere else, severity stopped being a
red-to-green heat ramp, and the diff's meaning moved from tint to text markers. The AC10 grayscale
capture run earned its place on first use: it found that Astro renders style-object values verbatim,
so **197 unitless spacing values across nine files were being silently discarded** by the browser —
a defect no DOM assertion could see.

## Phase 4 — the full product surface · **Complete (2026-08-19)**

Plan: `../plans/phase-4-full-product-surface.md`. Decided by **ADR-0070** (Accepted 2026-08-18). Closes the
distance between what the platform can do and what a person can reach: eight BFF routes have no UI at
all, and PR-9's write half — open, review, merge — has been reachable by `curl` and by nothing else
since T-0016.

Three waves under a **route-before-pixel** ordering law: **Tier A** (route exists, UI does not —
merge-request actions, code search, evidence packs, auditor grants; `webfrontend` only, may begin
now), **Tier B** (the PRD requires it, no route serves it — repository list, blame/history,
pipelines, policy authoring; backend first), **Tier C** (the `./UI` prototype shows it, nothing
requires it — issues, releases, settings, admin, ~~marketing page~~).

**Tier C is Done (2026-08-19), and not one of its five surfaces was adopted as the prototype drew
it.** Releases ship as tags and notes with no artifacts (ADR-0075); settings as a name, a description
and an archive label that restricts nothing (ADR-0076); the admin area as a dated fleet report and a
door into the existing grant flow, with no audit-log browser (ADR-0077); issues **not at all** — a
merge request references the tracker the customer already has (ADR-0074); and the marketing page
**withdrawn**, because a surface that must never receive a session needs its own repository and nobody
owns one (ADR-0078, PRD §5.1). Each deferral is held by a contract gate or a policy pin rather than by
a note, and T-0067 keeps the authenticated root from becoming the marketing page nobody built.

**Exit — all six criteria met (2026-08-19).** Every BFF route has a UI or a recorded reason it does
not; all eight nav destinations resolve to a page that exists (checked mechanically, not asserted);
PR-9's loop is executable by a person in a browser since T-0049; every surface added passes the
ADR-0069 gates, and since T-0077 the ADR-0079 dimension gate as well; `usage-regression-pins` and
`readonly-cause` are unmodified throughout. **EP-25, EP-26, EP-27 and EP-28 are Done.**

The phase's own summary is that it delivered less than the prototype drew and said so every time:
PR-26's job logs, PR-27's policy authoring, PR-30's visibility and members, PR-31's audit browser and
PR-28's tracker are all undelivered by decision, each held by a contract gate (checks 13–18) or a
policy pin rather than by a note — and PR-32 was withdrawn outright.

## Architecture evolution (ADR-0025 → ADR-0026)

Phases 0–3 ship as a **modular monolith per plane** (ADR-0025). A module becomes its own **coarse
service** (ADR-0026) only when a fitness-function trigger fires — distinct scaling profile,
isolation/blast-radius/compliance need, divergent SLO/deploy-cadence/ownership, or build/test/deploy
time crossing the ADR-0030 budget. Under BYO each extraction adds a pod to the customer's cluster, so
it must justify the footprint (G8). Triggers are measured (T-0009), not scheduled.

## Later / not scheduled

Registry hardening, packages, air-gapped installs (Topology A), advanced compliance frameworks.
