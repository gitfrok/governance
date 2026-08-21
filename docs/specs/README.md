# Specs

Spec-first behavioral descriptions (`../process/spec-driven-development.md`). Copy `_template.md`
→ `SPEC-####-<slug>.md`; a task's spec must be **Approved** before RED (tests). Approved specs
below carry Open Questions that flag any still-parked human decision.

**The lifecycle is `Draft → Approved → Implemented`** (`../process/spec-driven-development.md`), and
this index carries the same status as each spec's own file. **Reconciled 2026-08-19:** 52 specs whose
every task was Done had never left `Approved` — the state advanced in the tasks and not in the specs,
so the index answered "what may go RED" and not "what is built". Each now carries the date its last
task completed, taken from that task's exit record. A spec stays `Approved` while any of its tasks is
open: **SPEC-0045** is the only one, waiting on T-0042's real-cluster proof.

**SPEC-0012, SPEC-0013 and SPEC-0036 carry no task**, so nothing in the task table can advance them
and the reconcile deliberately left them alone. Each is enforced by a gate that exists —
`check-ceremony-tier.sh`, `check-dispatch-scope.sh`, and the modern-Go idiom pass respectively — so
`Approved` understates them; inferring a completion date from a script's existence would be inventing
one, which is worse than a status that is merely behind.

| Spec | Title | Status | Task(s) |
|------|-------|--------|---------|
| SPEC-0001 | Tenant isolation & RLS | Implemented (2026-08-06) | T-0004 |
| SPEC-0002 | Policy Decision Point | Implemented (2026-08-06) | T-0005 |
| SPEC-0003 | Append-only audit log | Implemented (2026-08-06) | T-0006 |
| SPEC-0004 | Git storage & transport | Implemented (2026-08-10) | T-0010, T-0011 |
| SPEC-0005 | Durable writes & failover | Implemented (2026-08-10) | T-0012 |
| SPEC-0006 | Identity & access | Implemented (2026-08-10) | T-0013 |
| SPEC-0007 | Repo read & BFF view | Implemented (2026-08-10) | T-0014 |
| SPEC-0008 | Web repo browsing UX | Implemented (2026-08-14) | T-0015 |
| SPEC-0009 | Merge requests & approval policy | Implemented (2026-08-10) | T-0016 |
| SPEC-0010 | CI v0 ephemeral isolation | Implemented (2026-08-10) | T-0017 |
| SPEC-0011 | Repository & review-history import | Implemented (2026-08-11) | T-0018 |
| SPEC-0012 | Ceremony tiers & session modes | Approved | — |
| SPEC-0013 | Dispatch scope boundary & worktree isolation | Approved | — |
| SPEC-0014 | Shell portability gate (macOS lane) | Implemented (2026-08-09) | T-0003 |
| SPEC-0015 | Git-RPC v1 contract | Implemented (2026-08-09) | T-0010 |
| SPEC-0016 | Identity credential authentication contract | Implemented (2026-08-10) | T-0013, T-0011 |
| SPEC-0017 | Repository read RPC contract | Implemented (2026-08-14) | T-0014, T-0015 |
| SPEC-0018 | Replica coordination & fencing contract | Implemented (2026-08-10) | T-0012 |
| SPEC-0019 | Merge request, review, and branch-protection contract | Implemented (2026-08-11) | T-0016, T-0018 |
| SPEC-0020 | CI v0 job dispatch and isolated-runner contract | Implemented (2026-08-10) | T-0017 |
| SPEC-0021 | Browser repository-view HTTP contract | Implemented (2026-08-14) | T-0015 |
| SPEC-0022 | SSH verifier-key routing | Implemented (2026-08-10) | T-0013, T-0011 |
| SPEC-0023 | Git LFS transport and object store | Implemented (2026-08-11) | T-0010, T-0018 |
| SPEC-0024 | Normalized findings model & scanner ingestion | Implemented (2026-08-14) | T-0022 |
| SPEC-0025 | Findings ingestion and read contract | Implemented (2026-08-14) | T-0022 |
| SPEC-0026 | Unified security dashboard & triage | Implemented (2026-08-14) | T-0023 |
| SPEC-0027 | Triage and dashboard-read contract | Implemented (2026-08-14) | T-0023 |
| SPEC-0028 | Findings on merge requests | Implemented (2026-08-14) | T-0024 |
| SPEC-0029 | Security & approval policy — versioned, dry-run, enforced | Implemented (2026-08-14) | T-0025 |
| SPEC-0030 | Policy decision-provenance and dry-run contract | Implemented (2026-08-14) | T-0025 |
| SPEC-0031 | Date-ranged evidence pack export | Implemented (2026-08-14) | T-0026 |
| SPEC-0032 | Evidence export contract | Implemented (2026-08-14) | T-0026 |
| SPEC-0033 | Scoped, read-only, time-boxed auditor access | Implemented (2026-08-14) | T-0027 |
| SPEC-0034 | Permission-filtered code search | Implemented (2026-08-14) | T-0028 |
| SPEC-0035 | Code search query and indexing contract | Implemented (2026-08-14) | T-0028 |
| SPEC-0036 | Modern Go idiom adoption across backend and bff | Approved | — |
| SPEC-0037 | CI scan report handoff to the findings plane | Implemented (2026-08-14) | T-0029 |
| SPEC-0038 | Agent enrolment and data-plane self-registration | Implemented (2026-08-15) | T-0030 |
| SPEC-0039 | BYO packaging, per-cloud drivers, signed reconcile upgrades | Implemented (2026-08-15) | T-0031, T-0032 |
| SPEC-0040 | Region and cloud pinning, demonstrable in the evidence pack | Implemented (2026-08-15) | T-0033 |
| SPEC-0041 | Fair-use metering and envelope behaviour | Implemented (2026-08-15) | T-0034 |
| SPEC-0042 | Durable agent and residency stores | Implemented (2026-08-15) | T-0036, T-0037 |
| SPEC-0043 | Residency Declare surface and placement hardening | Implemented (2026-08-15) | T-0038, T-0039 |
| SPEC-0044 | Agent-CA custody and rotation operations | Implemented (2026-08-15) | T-0040 |
| SPEC-0045 | Multi-cluster BYO readiness | Approved (amended 2026-08-15) | T-0041, T-0042 |
| SPEC-0046 | Usage view truth and the PR-7 read-only distinction | Implemented (2026-08-16) | T-0043, T-0044 |
| SPEC-0047 | CVD-first design system for the web frontend | Implemented (2026-08-17) | T-0045, T-0046, T-0047, T-0048 |
| SPEC-0048 | Merge-request actions — open, review, merge from the web UI | Implemented (2026-08-18) | T-0049 |
| SPEC-0049 | Code search — query, page, and an honest empty state | Implemented (2026-08-18) | T-0050 |
| SPEC-0050 | Evidence packs — request, watch and read a date-ranged pack | Implemented (2026-08-18) | T-0051 |
| SPEC-0051 | Auditor grants — issue, list and revoke scoped evidence access | Implemented (2026-08-18) | T-0052 |
| SPEC-0052 | A durable repository registry, and the list it makes possible | Implemented (2026-08-18) | T-0053, T-0054, T-0055 |
| SPEC-0053 | Blame and history, and the git-author/platform-actor distinction | Implemented (2026-08-19) | T-0056, T-0057, T-0058 |
| SPEC-0054 | Pipeline runs, and the plain statement that job output is gone | Implemented (2026-08-19) | T-0059, T-0060, T-0061 |
| SPEC-0055 | Policy visibility — what is in force and what decided an outcome | Implemented (2026-08-19) | T-0062, T-0063 |
| SPEC-0056 | Releases — a tag, some notes, and an honest answer when the tag moves | Implemented (2026-08-19) | T-0064, T-0065, T-0066 |
| SPEC-0057 | Repository settings — a name, a description, an archive label, and a record of who changed it | Implemented (2026-08-19) | T-0068, T-0069, T-0070 |
| SPEC-0058 | The admin area — a dated fleet report, and a door into the grant flow | Implemented (2026-08-19) | T-0071, T-0072, T-0073 |
| SPEC-0059 | A merge request references an issue that lives somewhere else | Implemented (2026-08-19) | T-0074, T-0075, T-0076 |
| SPEC-0060 | One type scale, one page shell, and a gate that keeps geometry in the token layer | Implemented (2026-08-19) | T-0077 |
| SPEC-0061 | The Code Review context keeps what it was told | Implemented (2026-08-21) | T-0078 |
| SPEC-0062 | The four-eyes floor | Implemented (2026-08-21) | T-0079 |
| SPEC-0063 | The Notifications context | Approved (2026-08-21) | T-0080 |
| SPEC-0064 | Draft merge requests | Implemented (2026-08-21) | T-0081 |
| SPEC-0065 | Merge strategies, and trunk-based landing as a mode | Approved (2026-08-21) | T-0082 |
