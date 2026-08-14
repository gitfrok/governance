# Tasks

One file per unit of work, `T-####-<slug>.md`, executed via the Agentic SDLC
(`../process/agentic-sdlc.md`) — spec-first, test-first. Copy `_template.md` to start. Each file's own
`Status:` and `Repo(s):` are authoritative; this table is the index.

| Task | Title | Phase | Status |
|------|-------|-------|--------|
| T-0001 | Scaffold super-repo + submodules (polyrepo + HCLC) | 0 | Done |
| T-0002 | Boundary/arch enforcement in CI | 0 | Done |
| T-0003 | Minikube dev environment | 0 | Done — AC1–AC4 verified; cluster lane is its open follow-up |
| T-0004 | Tenancy + RLS baseline | 0 | Done |
| T-0005 | PDP skeleton (OPA) | 0 | Done |
| T-0006 | Append-only audit log | 0 | Done |
| T-0007 | Storage benchmark (SeaweedFS-FUSE vs block) | 0 | Done — decided by ADR-0033 |
| T-0008 | In-process bus + module `api` convention | 0 | Done |
| T-0009 | Architecture fitness functions (extraction-readiness) | 0 | Done |
| T-0020 | Contract schema gate (`buf lint` + `buf breaking` + codegen freshness) | 0 | Done — AC5 amended to gate at the composition boundary |
| T-0010 | Git-RPC storage service | 1 | Done — backend #20 |
| T-0011 | Smart-HTTP + SSH front doors | 1 | Done — backend #27/#28 |
| T-0012 | Sync-replica write path + failover | 1 | Done — backend #30; demonstration needs the cluster lane |
| T-0013 | Identity & access: Zitadel + PATs | 1 | Done — backend #21/#37/#50, bff #22 |
| T-0014 | Repository read APIs + BFF aggregation | 1 | Done — backend #22/#24, bff #18 |
| T-0015 | Web: repo browser + file/diff + palette | 1 | Done — bff #22, webfrontend #20, super-repo #77; SPEC-0021 AC6 closed out at webfrontend@2fa6ffe |
| T-0016 | Merge requests + protected branches + approval policy | 1 | Done — backend #31/#33/#34/#35 |
| T-0017 | CI v0: gVisor sandbox runner + KEDA | 1 | Done — backend #29/#32, super-repo #76; dispatch needs a gVisor RuntimeClass |
| T-0018 | Repository & review-history import | 1 | Done — 23 of 24 criteria; AC19 moved to Phase 2 |
| T-0021 | Container images for both planes | 1 | Done — backend #19/#25, bff #16/#19, webfrontend #16/#18 |
| T-0022 | Normalized findings model + scanner ingestion | 2 | Done — contracts governance@8b4dac2, backend@acebf68; live identity proof re-ran green at the exit pins |
| T-0023 | Unified security dashboard + triage state | 2 | Done — contracts governance@bcd37c9, backend@acb4a9c, bff@d290e14, webfrontend@5b53c36 |
| T-0024 | Findings inline on the merge request | 2 | Done — contracts governance@6fa2a24, backend@c64e6a3, bff@47360c2, webfrontend@92804eb; AC4 host limit (cluster lane) |
| T-0025 | Security & approval policy: versioned, dry-run, enforced | 2 | Done — contracts governance@e412eb4, backend@67b0224 + e475683; merge gate composed in the live policy stack (composition harness) |
| T-0026 | Date-ranged evidence pack export | 2 | Done — contracts governance@178d97a, backend@9cfd392, bff@3c4ebe0; carries T-0018 AC19, proven live |
| T-0027 | Scoped, read-only, time-boxed auditor access | 2 | Done — contracts governance@a9a5c9b, backend@50bdc34 + 6e4696c, bff@77fac5e; live grant proof re-ran green |
| T-0028 | Permission-filtered code search | 2 | Done — contracts governance@011eb2a, backend@267eaa4 (merged into stack tip 6b66da4), bff@4b93d25; AC4 host limit (cluster lane) |
| T-0029 | CI scan report → findings ingest (`CIJobFinished` wiring) | 2 carry-over | Done — backend@49d6bfa; AC1–AC9 proven locally, AC10 cluster-lane deferral |
| T-0030 | Agent enrolment, self-registration, certificate rotation | 3 | Done — contracts governance@5e33e90 + authz governance@2c268d3, backend@8e5d013; SPEC-0038 AC1–AC9 proven by named tests |
| T-0031 | Helm chart, Operator, per-cloud driver seam | 3 | Done — backend@4b26cb2, super-repo@150cc2b; SPEC-0039 AC1/AC2 proven, AC8 real-state proof carried to the cluster lane |
| T-0032 | Signed releases, reconcile rollout, rollback | 3 | Done — governance@dea5476, backend@85b773c, super-repo@149b3e2; SPEC-0039 AC3–AC7 proven |
| T-0033 | Residency pinning and its evidence-pack section | 3 | Done — governance@0e61302, backend@c630a1e; SPEC-0040 AC1–AC8 proven |
| T-0034 | Fair-use metering, envelopes, usage view | 3 | Done — governance@5dff9b3, backend@d3f4ad6, bff@e2344de, webfrontend@95f77be+0e80261; SPEC-0041 AC1–AC10 proven |

## Retired numbers (never reused)

- **T-0019** — review-history import + attested provenance. Folded into T-0018 at SPEC-0011 review
  (open question 3): git data and review history ship as one unit of work.
