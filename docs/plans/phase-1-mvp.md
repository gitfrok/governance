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
| T-0013 Identity (Part A) | In progress | `modules/identity/` PAT/SSH foundation done; **OIDC login adapter not started** |
| T-0017 CI v0 | In progress | `modules/ci` on `feat/t0017-ci-runner`; domain+runner model done, **not wired to dataplane, no KEDA** |

Phase-1 tasks still **Todo / unbuilt** — the actual customer-facing MVP surface:

| Task | Spec(s) | What's missing |
|---|---|---|
| T-0012 sync-replica + failover | SPEC-0005 + 0018 (Approved), ADR-0016/0018/0042 | No `contracts/proto/replica/v1/replica.proto` exists; zero coordinator code; ReceivePack acks immediately |
| T-0015 web repo browser + palette | SPEC-0008 + SPEC-0021 (Approved) | `webfrontend/src/pages/` is a stub `index.astro`; BFF has no `browser/v1` handlers |
| T-0016 merge requests + protected branches | SPEC-0009 + SPEC-0019 (Approved), ADR-0004/0006/0007 | **No `modules/codereview`** in backend; `codereview.proto` drafted but no state machine, PDP rules, audit events, BFF/web views |
| T-0018 repo + history import | SPEC-0011 (Approved), ADR-0029 | Fully unstarted; `Depends on` T-0010/T-0006/T-0016/T-0013/T-0005 |

All Phase-1 specs are **Approved**. *Docs drift:* `docs/specs/README.md` still lists SPEC-0019 and
SPEC-0021 as `Draft` (their file headers say Approved) — correct the index as a drive-by.

## Workstreams & sequence (ADR-0027 order: governance → backend → bff → webfrontend → super-repo)

1. **Contracts & policies (governance, unblocks everything):**
   - Phase-1 plan file (this document).
   - `contracts/proto/replica/v1/replica.proto` (SPEC-0018) — shard record, fencing term, durable-primary/sync acks, CAS auto-promote, force-promote request.
   - `contracts/proto/bff/v1/browser.proto` (SPEC-0021) — tree/file/diff view messages + endpoints.
   - PDP Rego rules for MR open/review/merge + direct-push deny (SPEC-0019 policy vocabulary) and `merge_request.merge`, `codereview.review.approved`, `codereview.merge.approved` audit actions.
   - OIDC adapter spec/gap check (ADR-0045 specifies Auth Code + PKCE; session-encoding question resolved here).
   - Fix `specs/README.md` Draft→Approved drift for SPEC-0019/0021.
2. **Git plane (backend):** T-0012 coordinator in `git-storaged` + ReceivePack quorum ack; auto-promote; dual-loss read-only; audited force-promote.
3. **Identity (backend + bff):** T-0013 OIDC adapter in `modules/identity` + BFF session middleware turning an OIDC cookie into a tenant-scoped `ReadContext`.
4. **Code review (backend + bff + webfrontend):** T-0016 `modules/codereview` MR state machine + PDP gate + audit; BFF aggregation of `MergeRequestService`; minimal MR route in webfrontend.
5. **CI (backend):** T-0017 wire `modules/ci` to the dataplane app; KEDA ScaledObject on the job queue; ephemeral gVisor sandbox per job (invariants 3).
6. **Code UX (webfrontend + bff):** T-0015 BFF `browser/v1` handlers + Astro tree/file/diff routes + `Ctrl+K` command palette.
7. **Migration (governance → backend → webfrontend):** T-0018 last — depends on T-0016 + T-0013. Import RPCs, `Provenance`/`HistoryImported`/`HistoryImportRevoked` events, attested-history import, actor mapping, web rendering, evidence-pack appendix.
8. **Exit proof:** a single end-to-end scenario in Minikube (`make dev-up`) — OIDC login → clone → durable push (primary+sync) → open MR → direct push to protected ref denied → approve+merge → CI job runs + green gates merge → audit trail + git-node failover promotes in-sync replica.

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
- **T-0013 session encoding:** cookie vs bearer-token — pick here; ripples through BFF session middleware.
- **T-0017 runtime** is the riskiest step (agent/subprocess boundary, ADR-0011) — prototype before full rollout.
