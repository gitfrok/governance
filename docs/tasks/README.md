# Tasks

One file per unit of work, `T-####-<slug>.md`, executed via the Agentic SDLC
(`../process/agentic-sdlc.md`) — spec-first, test-first. Copy `_template.md` to start.

| Task | Title | Phase | Status |
|------|-------|-------|--------|
| T-0001 | Scaffold super-repo + submodules (polyrepo + HCLC) | 0 | Done |
| T-0002 | Boundary/arch enforcement in CI | 0 | Done |
| T-0003 | Minikube dev environment | 0 | Done |
| T-0004 | Tenancy + RLS baseline | 0 | Done |
| T-0005 | PDP skeleton (OPA) | 0 | Done |
| T-0006 | Append-only audit log | 0 | Done |
| T-0007 | Storage benchmark (SeaweedFS-FUSE vs block) | 0 | Done |
| T-0008 | In-process bus + module `api` convention | 0 | Done |
| T-0009 | Architecture fitness functions (extraction-readiness) | 0 | Done |
| T-0010 | Git-RPC storage service | 1 | Done |
| T-0011 | Smart-HTTP + SSH front doors | 1 | **Done** — backend #27/#28 |
| T-0012 | Sync-replica write path + failover | 1 | **Done** — backend #30 |
| T-0013 | Identity & access: Zitadel + PATs | 1 | Done — backend #37 (OIDC login), #21 (PAT/SSH) |
| T-0014 | Repository read APIs + BFF aggregation | 1 | Done |
| T-0015 | Web: repo browser + file/diff + palette | 1 | In review — bff #22, webfrontend #20 (code merged on branch; awaiting review) |
| T-0016 | Merge requests + protected branches + approval policy | 1 | Done — backend #31/#33/#34/#35 (MR lifecycle, protection, merge ref move) |
| T-0017 | CI v0: gVisor sandbox runner + KEDA | 1 | Done — backend #29/#32, deploy PR #76 (ScaledObject); dev cluster limit: no gVisor RuntimeClass under rootless podman |
| T-0018 | Repository & review-history import | 1 | In review — governance #110 (contracts), backend #39 (provenance boundary + git phase + import service) |
| T-0020 | Contract schema gate (`buf lint` + `buf breaking` + codegen freshness) | 0 | Done |
| T-0021 | Container images for both planes | 1 | **Done** — backend #19/#25, bff #16/#19, webfrontend #16/#18 |

## Retired numbers (never reused)
- **T-0019** — Review-history import + attested provenance. Folded into T-0018 at SPEC-0011 review
  (open question 3): git data and review history ship as one unit of work.
