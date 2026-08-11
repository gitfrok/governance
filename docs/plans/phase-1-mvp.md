# Plan — Phase 1: MVP (GitHub-lite)

**Status:** **Complete (2026-08-11)**
**Objective:** a team can host a repo, open/review/merge an MR, and run a pipeline (PRD §5, roadmap
§Phase 1).

Every Phase-1 task is Done. Task files carry their own `Status:` and evidence; this plan records the
sequencing that produced them and the exit verdict.

| Task | Landed as |
|---|---|
| T-0010 Git-RPC service | `backend/git-storaged/server.go` — UploadPack/ReceivePack + RepositoryReader |
| T-0011 Smart-HTTP + SSH | real `git clone`/`push` over HTTPS and SSH (backend #27/#28) |
| T-0012 sync-replica + failover | `modules/repository/internal/replica` coordinator + quorum ack (#30) |
| T-0013 Identity (OIDC + PATs) | PAT/SSH foundation, `ExchangeCode`/`VerifyIDToken` (#37), roles-on-PAT (#50) |
| T-0014 Repo read APIs + BFF | `bff/internal/repositoryreader`, `modules/repository` |
| T-0015 Web repo browser + palette | bff #22, webfrontend #20, super-repo #77 — `app.gitsaas.test` serving |
| T-0016 Merge requests | `modules/codereview` lifecycle + PDP gate + audit + protection projection, authorized merge ref move, direct-push denial (#31/#33/#34/#35) |
| T-0017 CI v0 | `modules/ci` sandbox model + K8s Jobs (#32) + KEDA `ScaledObject` (super-repo #76) |
| T-0018 Repo + history import | contracts (#110/#114/#116), git phase + import service (#39/#40), actor mapping + LFS (#45), object tier (#46), read surface (bff #25), rendering (webfrontend #23) |
| T-0021 Container images | dataplane, controlplane, bff and webfrontend SSR images |

## Workstream order (ADR-0027: governance → backend → bff → webfrontend → super-repo)

Contracts and policies first, because they unblock everything: replica, browser, codereview, CI and
import contracts, the PDP Rego rules, ADR-0045. Then the git plane (T-0012 quorum ack, auto-promote,
dual-loss read-only, audited force-promote), identity, code review, CI, code UX, and migration last —
terminal behind T-0016 and T-0013.

**Critical path:** T-0012 (durability/ack) ⟷ T-0016 (MR gate) ⟷ T-0017 (CI gate) — the exit bar needs
a durable push, an MR gated by policy, and a pipeline whose status gates merge. T-0013 gates the web
session for both T-0015 and T-0016.

## Exit criteria

| # | Criterion | Verdict (2026-08-11) |
|---|---|---|
| 1 | T-0010–T-0018 + T-0021 Done in `../tasks/README.md` | **met** — T-0018 was the last |
| 2 | the end-to-end Minikube scenario passes | **met except two infrastructure-bound steps** (below) |
| 3 | CI gates green per `../process/ci-gates.md` | **met on every merged PR**, with the two gaps that file records: backend integration tests skip without `TEST_DATABASE_URL`, live-infrastructure suites skip without their endpoints |

The scenario is **OIDC login → clone → durable push → open MR → direct push to a protected ref denied
→ approve and merge → CI job runs and gates merge → audit trail → failover promotes the in-sync
replica.** Its code-driven half was executed live on 2026-08-11: push, protected-ref denial and audit,
`SetBranchProtection` forwarded to storage, MR open (refs announced cross-process via
`GitStorage.SubscribeRefUpdates`, #128), approve, merge, `main` moved. Host DNS is wired on the
verified host and `make dev-smoke` passes every host by name. The command flow is in the super-repo's
`deploy/MVP-RUNBOOK.md` §8a.

Two steps are **not demonstrable on a single non-hypervisor node**, and neither is missing code:

1. **CI dispatch** — no gVisor RuntimeClass under rootless podman (T-0017). The sandbox model and the
   K8s Job path are implemented.
2. **Durability quorum and failover promotion** — one git node. Both are proved by T-0012's tests and
   T-0018's two-node integration suite; the cluster cannot supply a second physical node.

Both are tracked against **T-0003's cluster lane**, not against this phase.

## What Phase 1 changed about storage

**ADR-0050 (Accepted 2026-08-11)** narrows ADR-0020: LFS objects, CI artifacts and container-image
blobs come from a **SeaweedFS FUSE mount**, not the S3 gateway, produced by ADR-0051's privileged node
DaemonSet. ADR-0033 is untouched — live bare repositories stay on block volumes and `git-storaged`
refuses a FUSE repository root (invariant 7). Because a mount has no signed URLs, SPEC-0023's
pre-signed decision is superseded for that tier: transfers proxy through the plane under
`repo.lfs.read` / `repo.lfs.write`, and every read is verified against the digest in the object's name
before a byte reaches a client.

The dev cluster runs the **S3 adapter** ADR-0050 decision 6 keeps for a deployment without a mount:
ADR-0051's DaemonSet was built and its mount does not propagate on that driver, measured rather than
assumed (super-repo `deploy/dev/README.md`).

## Lessons the phase paid for

Proving T-0018's AC1 and AC2 against live infrastructure rather than fakes found three defects that
had all passed review: `git fetch` with no refspec landed objects and tags but **no branches**, so an
import reported success and produced a repository nothing could reach; `authz.rego` granted
`repository.import` to **no role**, so AC20 had "passed" only because nobody could import; and
SeaweedFS answers **200 to a PUT into a bucket that does not exist**, so the object tier now reads
every write back before acknowledging it. Wiring the tier found a fourth — the S3 gateway served every
object to unsigned requests, because the credentials sat on SeaweedFS's `anonymous` identity.

**A test against a fake proves the control flow, not the claim.** Prefer a live proof for anything an
acceptance criterion rests on.

## Decisions taken during the phase

- **AC19 of T-0018 — the evidence-pack criterion — moved to Phase 2** (2026-08-10, recorded in
  `../backlog/README.md` under EP-8). No evidence-pack surface exists to satisfy it; ADR-0029 §4 binds
  whoever builds one.
- **MR UI scope:** the minimal MR page shipped (super-repo #81); rich review threads stay deferred.
- **T-0013 session encoding:** opaque server-side cookie per ADR-0049, implemented by the BFF session
  middleware (bff #22). **ADR-0049 is still `Proposed`** — accepting it is outstanding.
- **CI as merge-gate:** shipped observable to the bar; gating merge on CI status is a follow-up.
