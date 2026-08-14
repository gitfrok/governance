# Specs

Spec-first behavioral descriptions (`../process/spec-driven-development.md`). Copy `_template.md`
→ `SPEC-####-<slug>.md`; a task's spec must be **Approved** before RED (tests). Approved specs
below carry Open Questions that flag any still-parked human decision.

| Spec | Title | Status | Task(s) |
|------|-------|--------|---------|
| SPEC-0001 | Tenant isolation & RLS | Approved | T-0004 |
| SPEC-0002 | Policy Decision Point | Approved | T-0005 |
| SPEC-0003 | Append-only audit log | Approved | T-0006 |
| SPEC-0004 | Git storage & transport | Approved | T-0010, T-0011 |
| SPEC-0005 | Durable writes & failover | Approved | T-0012 |
| SPEC-0006 | Identity & access | Approved | T-0013 |
| SPEC-0007 | Repo read & BFF view | Approved | T-0014 |
| SPEC-0008 | Web repo browsing UX | Approved | T-0015 |
| SPEC-0009 | Merge requests & approval policy | Approved | T-0016 |
| SPEC-0010 | CI v0 ephemeral isolation | Approved | T-0017 |
| SPEC-0011 | Repository & review-history import | Approved | T-0018 |
| SPEC-0012 | Ceremony tiers & session modes | Approved | — |
| SPEC-0013 | Dispatch scope boundary & worktree isolation | Approved | — |
| SPEC-0014 | Shell portability gate (macOS lane) | Approved | T-0003 |
| SPEC-0015 | Git-RPC v1 contract | Approved | T-0010 |
| SPEC-0016 | Identity credential authentication contract | Approved | T-0013, T-0011 |
| SPEC-0017 | Repository read RPC contract | Approved | T-0014, T-0015 |
| SPEC-0018 | Replica coordination & fencing contract | Approved | T-0012 |
| SPEC-0019 | Merge request, review, and branch-protection contract | Approved | T-0016, T-0018 |
| SPEC-0020 | CI v0 job dispatch and isolated-runner contract | Approved | T-0017 |
| SPEC-0021 | Browser repository-view HTTP contract | Approved | T-0015 |
| SPEC-0022 | SSH verifier-key routing | Approved | T-0013, T-0011 |
| SPEC-0023 | Git LFS transport and object store | Approved | T-0010, T-0018 |
| SPEC-0024 | Normalized findings model & scanner ingestion | Approved | T-0022 |
| SPEC-0025 | Findings ingestion and read contract | Approved | T-0022 |
| SPEC-0026 | Unified security dashboard & triage | Approved | T-0023 |
| SPEC-0027 | Triage and dashboard-read contract | Approved | T-0023 |
| SPEC-0028 | Findings on merge requests | Approved | T-0024 |
| SPEC-0029 | Security & approval policy — versioned, dry-run, enforced | Approved | T-0025 |
| SPEC-0030 | Policy decision-provenance and dry-run contract | Approved | T-0025 |
| SPEC-0031 | Date-ranged evidence pack export | Approved | T-0026 |
| SPEC-0032 | Evidence export contract | Approved | T-0026 |
| SPEC-0033 | Scoped, read-only, time-boxed auditor access | Approved | T-0027 |
| SPEC-0034 | Permission-filtered code search | Approved | T-0028 |
| SPEC-0035 | Code search query and indexing contract | Approved | T-0028 |
| SPEC-0036 | Modern Go idiom adoption across backend and bff | Approved | — |
| SPEC-0037 | CI scan report handoff to the findings plane | Approved | T-0029 |
