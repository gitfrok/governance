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
interactive mkcert/ingress step on this host).

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
  Phase-2 carried set, in order: first the **`CIJobFinished`→ingest wiring, which is unbuilt** — the
  pinned backend has no `CIJobFinished` subscriber and scan ingest is RPC-only, so the event-driven
  ingest must be built before any freshness measurement can observe it; then **CI-dispatched scans**
  (gVisor), then the measured demonstrations — **T-0024 AC4 measured findings freshness** and
  **T-0028 AC4 measured index freshness** — and the **exit-scenario live-cluster walk** the dev host
  could not host.

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

## Phase 3 — BYO *(to be expanded)*

Agent implementation (`contracts/proto/agent/v1`); Operator + Helm + per-cloud drivers; metering →
billing.

## Parked — needs a human decision first

Force-promote tenant self-service (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017) ·
unit-economics model per tier (ADR-0008) · event catalog (ADR-0022 — the boundary linter shipped in
T-0002/T-0009; the names exist as protobuf full names, nothing documents them).
