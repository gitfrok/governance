# Plan — Phase 1: MVP (GitHub-lite)

**Status:** In progress
**Objective:** A team can host a repo, open/review/merge an MR, and run a pipeline. (PRD §5, roadmap §Phase 1.)

## Current state (verified 2026-08-11)

Phase 0 is **Closed**. Enablers landed: T-0001…T-0009, T-0020, T-0021 (container images for both
planes, 2026-08-10). **Every Phase-1 task is now Done**, which satisfies the first of the three exit
criteria below and none of the other two — see [Exit criteria](#exit-criteria) for what that leaves.

| Task | Status | Reality on disk |
|---|---|---|
| T-0010 Git-RPC service | Done | `backend/git-storaged/server.go` implements UploadPack/ReceivePack + RepositoryReader |
| T-0011 Smart-HTTP + SSH | Done | `git clone`/`push` over HTTPS+SSH passing tests (backend `feat/t0011-dataplane-front-doors`) |
| T-0014 Repo read APIs + BFF | Done | `bff/internal/repositoryreader`; `modules/repository` |
| T-0021 Container images | Done | dataplane + controlplane + bff + webfrontend SSR images |
| T-0013 Identity (OIDC + PATs) | Done | `modules/identity/` PAT/SSH foundation + OIDC login (`ExchangeCode`/`VerifyIDToken`, backend #37) |
| T-0012 sync-replica + failover | Done | `modules/repository/internal/replica` coordinator + `git-storaged` quorum ack (backend #30) |
| T-0017 CI v0 | Done | `modules/ci` sandbox model + K8s Jobs (#32) + KEDA `ScaledObject` (super-repo #76). Dev-cluster limit: no gVisor RuntimeClass under rootless podman, so dispatch is unconfigured there |
| T-0016 merge requests | Done | `modules/codereview` lifecycle + PDP gate + audit + protection projection (#31) + authorized merge ref move (#33/#34) + direct-push denial (#35) |
| T-0015 web repo browser + palette | Done | bff #22, webfrontend #20, super-repo #77; `app.gitsaas.test` serving on minikube |
| T-0018 repo + history import | Done | contracts (governance #110/#114/#116), git phase + import service + GitHub history (backend #39/#40), actor mapping + LFS transport (#45), FUSE object tier (#46), imported-history read surface (bff #25), provenance rendering (webfrontend #23) |

### What T-0018 changed about storage, and what it did not

**ADR-0050 (Accepted 2026-08-11)** narrows ADR-0020: LFS objects, CI artifacts and container-image
blobs are served from a **SeaweedFS FUSE mount**, not the S3 gateway. ADR-0033 is untouched — live
bare repositories stay on block volumes, and `git-storaged` still refuses a FUSE repository root
(invariant 7). Because a mount has no signed URLs, SPEC-0023's pre-signed decision is superseded for
that tier: transfers proxy through the plane under `repo.lfs.read` / `repo.lfs.write`, and every read
is verified against the digest in the object's name before a byte reaches a client.

Three defects were found by proving AC1 and AC2 on real infrastructure rather than against fakes, and
all three would have shipped:

1. `git fetch` with no refspec landed objects and tags but **no branches** — imports reported success
   and produced repositories nothing could reach.
2. `authz.rego` granted `repository.import` to **no role**, so every import in a real deployment was
   denied. AC20 had "passed" only because nobody could import.
3. SeaweedFS answers **200 to a PUT into a bucket that does not exist**. The object tier now reads an
   object back before acknowledging a write.

## Workstreams & sequence (ADR-0027 order: governance → backend → bff → webfrontend → super-repo)

1. **Contracts & policies (governance, unblocks everything):** DONE — replica/browser/codereview/CI
   contracts, PDP Rego rules, OIDC ADR-0045, import contracts (#110).
2. **Git plane (backend):** DONE — T-0012 coordinator + quorum ack, auto-promote, dual-loss read-only,
   audited force-promote; ImportRefs git phase.
3. **Identity (backend + bff):** DONE — T-0013 OIDC adapter + BFF session middleware (ADR-0049).
4. **Code review (backend + bff + webfrontend):** DONE — backend (#31/#33/#34/#35), the BFF MR
   aggregation client (bff #22) and the minimal MR web surface (webfrontend, super-repo #81).
5. **CI (backend):** DONE — `modules/ci` wired to the dataplane app, KEDA ScaledObject on the job
   queue, ephemeral gVisor sandbox per job. Dev cluster limit recorded.
6. **Code UX (webfrontend + bff):** DONE — bff #22 + webfrontend #20, merged and serving.
7. **Migration (governance → backend → bff → webfrontend):** DONE — contracts, audit boundary, git
   phase, import service, GitHub history phase, declared-actor mapping, the LFS transport and its
   FUSE object tier (ADR-0050), the imported-history read surface and provenance rendering.
8. **Exit proof:** a single end-to-end scenario in Minikube (`make dev-up`) — OIDC login → clone →
   durable push (primary+sync) → open MR → direct push to protected ref denied → approve+merge →
   CI job runs + green gates merge → audit trail + git-node failover promotes in-sync replica.
   **This is the workstream that remains**, and it is the only one.

## Critical path
T-0012 (durability/ack path) ⟷ T-0016 (MR gate) ⟷ T-0017 (CI gate). The exit bar needs all three:
a durable push, an MR gated by policy, and a pipeline whose status gates merge. T-0013 (OIDC) gates
the web session for both T-0015 and T-0016 UI; T-0018 is terminal behind T-0016 + T-0013.

## Exit criteria

| # | Criterion | State (2026-08-11) |
|---|---|---|
| 1 | T-0010–T-0018 + T-0021 marked **Done** in `tasks/README.md` | **met** — T-0018 was the last, closed 2026-08-11 |
| 2 | the end-to-end Minikube scenario above passes | **not met** — see below |
| 3 | CI gates green per `ci-gates.md` | **met on every merged PR**, with the two standing gaps `ci-gates.md` already records: backend integration tests skip without `TEST_DATABASE_URL`, and the live-infrastructure suites skip without their endpoints |

Criterion 2 is the whole of what is left, and it is **not blocked on code** — every step of the
scenario is implemented and tested. Four things block it in a cluster, three of them environmental:

1. **No object tier is wired into any deployment.** `deploy/dev/` sets neither
   `GITFROK_SEAWEEDFS_MOUNT` nor the five `GITFROK_SEAWEEDFS_S3_*` variables, so the dev cluster
   serves no LFS at all — the tier is configured-or-absent by design, and it is absent. Wiring the
   mount per ADR-0050 is a super-repo change and the shortest path to closing the storage half.
2. **No gVisor RuntimeClass under rootless podman**, so CI dispatch is unconfigured in the dev
   cluster (recorded against T-0017). The sandbox model and the K8s Job path are implemented.
3. **One git node**, so the durability quorum and the failover promotion cannot be *demonstrated*
   there. Both are proved by T-0012's tests and by T-0018's two-node integration suite; what the
   cluster cannot supply is a second physical node — T-0003's lane.
4. **Host DNS for `*.gitsaas.test` is still a manual root step.** `dev-up.sh` prints the snippet and
   does not apply it; the smoke test reports this as its own distinct failure rather than a generic
   red.

The MVP deploy runbook in the super-repo (`deploy/MVP-RUNBOOK.md`) is the operational counterpart to
this section: same facts, ordered as steps rather than as criteria.

## Risks / decisions needed
- **CI as merge-gate vs observable run:** ship CI non-blocking to the bar, gate merge in a Phase-1 follow-up.
- **MR UI scope for the bar:** **resolved** — the minimal MR page shipped (super-repo #81); rich
  review threads stay deferred.
- **AC19 of T-0018 — the evidence-pack criterion — moved to Phase 2** (decided 2026-08-10, recorded
  in the backlog under EP-8). It asks that an evidence pack spanning an import carry zero attested
  records in its control sections, with attested history confined to a labelled appendix (SPEC-0011
  AC14, bound by ADR-0029 §4). **No evidence-pack surface exists yet to satisfy it**, which is why it
  moved rather than staying open against a task whose other 23 criteria are met.
- **T-0013 session encoding:** **resolved** — opaque server-side cookie per ADR-0049; the BFF session
  middleware implements it (bff #22).
- **T-0017 runtime** is the riskiest step (agent/subprocess boundary, ADR-0011) — the sandbox model
  and K8s Jobs are implemented; the dev cluster cannot run gVisor (recorded limit), so the in-cluster
  proof is pending a cluster with the RuntimeClass.
