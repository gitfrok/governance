# Plan — Phase 1: MVP (GitHub-lite)

**Status:** In progress
**Objective:** A team can host a repo, open/review/merge an MR, and run a pipeline. (PRD §5, roadmap §Phase 1.)

## Current state (verified 2026-08-10)

Phase 0 is **Closed**. Enablers landed: T-0001…T-0009, T-0020, T-0021 (container images for both
planes, 2026-08-10). Phase-1 tasks with real code already merged:

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

Phase-1 tasks **in review** (code complete, awaiting PR review to merge):

| Task | PRs | What's there |
|---|---|---|
| T-0015 web repo browser + palette | bff #22, webfrontend #20, super-repo #77 | BFF session + OIDC login flow + `/v1/repositories/*` browser surface; webfrontend tree/file/diff/raw SSR routes + Ctrl+K palette; deploy manifests + ingress `app.gitsaas.test` |
| T-0018 repo + history import | governance #110, backend #39 | Contracts (Provenance, ImportService, HistoryImported/Revoked, ImportRefs); audit-writer FIRST_PARTY boundary (AC11/AC24); ImportRefs git phase (AC1-AC3); import service state machine (AC6/AC7/AC10/AC16/AC17). History phase + web rendering remain |

## Workstreams & sequence (ADR-0027 order: governance → backend → bff → webfrontend → super-repo)

1. **Contracts & policies (governance, unblocks everything):** DONE — replica/browser/codereview/CI
   contracts, PDP Rego rules, OIDC ADR-0045, import contracts (#110).
2. **Git plane (backend):** DONE — T-0012 coordinator + quorum ack, auto-promote, dual-loss read-only,
   audited force-promote; ImportRefs git phase.
3. **Identity (backend + bff):** DONE — T-0013 OIDC adapter + BFF session middleware (ADR-0049).
4. **Code review (backend + bff + webfrontend):** backend DONE (#31/#33/#34/#35); the BFF MR
   aggregation client exists (bff #22); minimal MR web route remains.
5. **CI (backend):** DONE — `modules/ci` wired to the dataplane app, KEDA ScaledObject on the job
   queue, ephemeral gVisor sandbox per job. Dev cluster limit recorded.
6. **Code UX (webfrontend + bff):** code complete (bff #22 + webfrontend #20), in review.
7. **Migration (governance → backend → webfrontend):** contracts + audit boundary + git phase +
   import service done (governance #110, backend #39); history phase (source API client) and web
   provenance rendering remain.
8. **Exit proof:** a single end-to-end scenario in Minikube (`make dev-up`) — OIDC login → clone →
   durable push (primary+sync) → open MR → direct push to protected ref denied → approve+merge →
   CI job runs + green gates merge → audit trail + git-node failover promotes in-sync replica.

## Critical path
T-0012 (durability/ack path) ⟷ T-0016 (MR gate) ⟷ T-0017 (CI gate). The exit bar needs all three:
a durable push, an MR gated by policy, and a pipeline whose status gates merge. T-0013 (OIDC) gates
the web session for both T-0015 and T-0016 UI; T-0018 is terminal behind T-0016 + T-0013.

## Exit criteria
All eight Phase-1 tasks T-0010–T-0018 + T-0021 marked **Done** in `tasks/README.md`; the end-to-end
Minikube scenario above passes; CI gates green per `ci-gates.md` (unit + contract + integration +
boundary/arch + policy/tenant-isolation + version-floor + lint).

## Risks / decisions needed
- **CI as merge-gate vs observable run:** ship CI non-blocking to the bar, gate merge in a Phase-1 follow-up.
- **MR UI scope for the bar:** minimal MR page is sufficient; defer rich review threads.
- **T-0013 session encoding:** **resolved** — opaque server-side cookie per ADR-0049; the BFF session
  middleware implements it (bff #22).
- **T-0017 runtime** is the riskiest step (agent/subprocess boundary, ADR-0011) — the sandbox model
  and K8s Jobs are implemented; the dev cluster cannot run gVisor (recorded limit), so the in-cluster
  proof is pending a cluster with the RuntimeClass.
