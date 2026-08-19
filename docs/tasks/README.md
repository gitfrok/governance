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
| T-0035 | Apply the envelope throttle in the data plane | 3 | Done — backend@a9ed620 + super-repo pin 9f526d0; SPEC-0041 AC5/AC9 second half proven; decision "Both" recorded; AC5 live-git half carried to the E2E/cluster lane |
| T-0036 | Durable agent stores — enrolment-token store + data-plane registry Postgres adapters | 3.1 | Done — backend@c9e58c5; SPEC-0042 AC1/AC2/AC6/AC5 (agent half) proven real-Postgres |
| T-0037 | Durable residency declarations + evidence-pack assembly from durable projections | 3.1 | Done — backend@816cb30; SPEC-0042 AC3/AC4/AC5 (residency half) proven real-Postgres; closes T-0033's in-memory-store limit |
| T-0038 | Residency Declare wire surface — residency/v1, verified caller, control-plane implementation, PDP binding | 3.1 | Done — governance@794f578/3b9e853 (bundle 0.10.0) + backend@f182761; SPEC-0043 AC1/AC5/AC6/AC7 proven; closes T-0033's Declare-wire limit |
| T-0039 | PlacementGate hardening + placement-facts contradiction visibility | 3.1 | Done — backend@f182761; SPEC-0043 AC2–AC4 proven (matrix, tie-break, gate) |
| T-0040 | Agent-CA custody — OpenBao deployment, KMS signing, staged CA-trust-bundle rotation, runbook | 3.1 | Done — super-repo@31c9b45 deployment + backend@b0ab32e + super-repo@f8449b8; SPEC-0044 AC1–AC5 proven; EP-21 complete; honest "not run" rows recorded |
| T-0041 | Signed operator image + cross-plane release-trust-bundle distribution/rotation | 3.1 | Done — SPEC-0045 AC1, AC2 harness half, AC4, AC5 proven; contracts governance@b5128b0, backend@762d5f0 + a669cef, super-repo@febf0f7; AC2 real-cluster half + AC3 carried to T-0042 |
| T-0042 | Real-cluster conformance proof — GKE/EKS/AKS | 3.1 | Todo — SPEC-0045 AC3 + AC2 real half, SPEC-0039 AC8; EP-22; blocked-by T-0003 cluster lane |
| T-0043 | Usage-view divergence health gates + envelope-state telemetry through bff → webfrontend | 3.1 | Done — backend@bc30abd + bff@4059a23 + webfrontend@08f42c4; SPEC-0046 AC1–AC3/AC5; additive contract governance-first (b425db0, 36f284b); AC3 live-cluster half carried to the E2E lane |
| T-0044 | PR-7 durability read-only vs envelope-throttle distinction in UI/API | 3.1 | Done — backend@0238dee cause contract + webfrontend@843a195 distinction; SPEC-0046 AC4/AC5; EP-23 complete; proto half + live-page wiring carried to PR-7's product work |
| T-0045 | Design token foundation, self-hosted fonts, app shell | 3.5 | Done — webfrontend@cdf032c; SPEC-0047 AC1–AC4; EP-24; hex-literal gate ships as a ratchet, 15 files carried to T-0046..T-0048 |
| T-0046 | Repo browsing and the CVD-safe blue/orange diff | 3.5 | Done — webfrontend@089c514; SPEC-0047 AC5/AC6; EP-24 |
| T-0047 | Security, merge request and compliance surfaces on tokens | 3.5 | Done — webfrontend@0f0dabd; SPEC-0047 AC6/AC7; EP-24; hex ratchet reached zero |
| T-0048 | Usage view and code search on tokens, pins unmodified | 3.5 | Done — webfrontend@56c91d1, AC10 captures @ad075f4; SPEC-0047 AC8/AC9/AC10; EP-24; the capture review found 197 dropped spacing values |
| T-0049 | Open, review and merge a merge request from the web UI | 4 | Done — webfrontend@6d61827; SPEC-0048 AC1–AC11; EP-25; found the form-encoding and enum-name traps before code |
| T-0050 | Code search in the web UI, with an honest empty state | 4 | Done — webfrontend@a668de5; SPEC-0049 AC1–AC12; EP-25 complete; also fixed seven pages nesting a second `<main>` landmark |
| T-0051 | Request, watch and read an evidence pack from the web UI | 4 | Done — webfrontend@1141bc5; SPEC-0050 AC1–AC11; EP-25; the capture review caught a "Ready" badge above a truncation notice |
| T-0052 | Issue, list and revoke auditor grants from the web UI | 4 | Done — webfrontend@1141bc5; SPEC-0051 AC1–AC11; EP-25; no function here turns an expiry into a state |

| T-0053 | Durable repository registry — the Postgres store owed since T-0004 | 4 | Done — backend@79479a8+0c853b1; SPEC-0052 AC1–AC6; EP-26; isolation proofs 6/6 with **0 skips**, and the arch gate refused the first design |
| T-0054 | ListRepositories on the wire, and the BFF route | 4 | Done — governance@1534a70, backend@0c853b1, bff@1c52899; SPEC-0052 AC7–AC9; EP-26; the first contract commit put the RPC on the process that cannot answer it |
| T-0055 | The repository landing page, replacing the T-0001 stub | 4 | Done — webfrontend@39e224b; SPEC-0052 AC10–AC13; EP-26; the AC11 enumeration caught its own copy |

| T-0056 | History and blame in git-storaged | 4 | Done — backend@d72998d; SPEC-0053 AC1–AC6; EP-26; AC4 amended — a leading dash is a legal filename, the separator is its defence |
| T-0057 | GetHistory and GetBlame on the wire, and the BFF routes | 4 | Done — governance@eb7b131, bff@1f38368; SPEC-0053 AC7–AC9; EP-26; check-contracts gained check 12 |
| T-0058 | The blame and history views | 4 | Done — webfrontend@38fcd95; SPEC-0053 AC10–AC14; EP-26; no avatar, no profile link, no `<img>` |

| T-0059 | Durable CI job history and the runs list | 4 | Done — backend@94a55c1; SPEC-0054 AC1–AC6; EP-26; 7 real-Postgres proofs, **0 skips** |
| T-0060 | ListJobs on the wire, and the BFF route | 4 | Done — governance@5a696d5, backend@a7e467c, bff@6ce38c6; SPEC-0054 AC7–AC9; EP-26; check 13 keeps logs deferred |
| T-0061 | The pipeline runs view | 4 | Done — webfrontend@044cc59; SPEC-0054 AC10–AC14; EP-26; the capture review caught Queued and Cancelled sharing a glyph |
| T-0062 | Bundle status on the wire, and the BFF route | 4 | Done — governance@4364870, backend@a09042f, bff@790e8d5; SPEC-0055 AC1–AC3; EP-26; check 14 keeps authoring deferred |
| T-0063 | The policy visibility view | 4 | Done — webfrontend@c152501; SPEC-0055 AC4–AC10; EP-26; the absence is not a permission |

| T-0064 | Releases context, durable store, and tag listing | 4 | Done — backend@4668f75; SPEC-0056 AC1–AC7; EP-27; 8 real-Postgres proofs, **0 skips** |
| T-0065 | The release contract and BFF routes | 4 | Done — governance@a213d28, bff@9a76f1b; SPEC-0056 AC8–AC10; EP-27; check 15 keeps artifacts out |
| T-0066 | The releases view | 4 | Done — webfrontend@1f5fd65; SPEC-0056 AC11–AC16; EP-27; a release whose tag moved says so |

| T-0067 | Guard the authenticated root against becoming a marketing page | 4 | Todo — ADR-0078 decision 3; EP-27; nothing to move, so the rule is made enforceable instead |

## Retired numbers (never reused)

- **T-0019** — review-history import + attested provenance. Folded into T-0018 at SPEC-0011 review
  (open question 3): git data and review history ship as one unit of work.
