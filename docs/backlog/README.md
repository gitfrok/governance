# Backlog — epics

Epics are grouped by roadmap phase and link down to executable tasks in `../tasks/`.
**Definition of Done** for every task: `../process/definition-of-done.md`.

## Phase 0 — Foundations
- **EP-0 Scaffolding & process**: T-0001 (repo layout, **Done**), T-0002 (boundary/arch CI),
  T-0008 (in-process bus + module `api` convention), T-0009 (extraction-readiness fitness
  functions). T-0008 and T-0009 carry `Phase / Epic: 0 / EP-0` in their task files and were
  missing from this list.
  **Epic status:** T-0001 Done; T-0002/T-0008/T-0009 In review. EP-0 cannot close until
  **T-0002 AC5** (a second GitHub org member, so `enforce_admins=true` can be set without making
  merges impossible) and **ADR-0030** (the extraction budgets T-0009 AC4 gates on) are settled —
  both need a human, neither is code.
- **EP-1 Platform up**: T-0003 (Minikube dev env).
- **EP-2 Tenancy & governance base**: T-0004 (tenancy+RLS), T-0005 (PDP), T-0006 (audit log).
- **EP-3 Storage decision**: T-0007 (SeaweedFS-FUSE vs block-volume benchmark).

## Phase 1 — MVP
- **EP-4 Git plane**: T-0010 (Git-RPC), T-0011 (smart-HTTP+SSH), T-0012 (sync-replica+failover).
- **EP-5 Identity**: T-0013 (Zitadel + PATs, tenant scoping).
- **EP-6 Code UX**: T-0014 (repo read APIs + BFF), T-0015 (web browser/diff/palette).
- **EP-7 Review & CI**: T-0016 (MR + protected branches + approval policy), T-0017 (CI v0 gVisor+KEDA).
- **EP-8 Migration**: T-0018 (repository + review-history import — refs/tags/LFS *and* MR history
  with attested provenance, one unit of work). Scoped in by PRD PR-12; **ADR-0029 Accepted**,
  **SPEC-0011 Approved** — ready to start. T-0019 was folded into T-0018 at spec review.

## Phase 2 — Ultimate wedge  *(to be expanded)*
Scanner integration; unified security dashboard; security/approval policies-as-code; audit
UI + evidence export; Zoekt search.

## Phase 3 — BYO  *(to be expanded)*
Agent impl (`contracts/proto/agent/v1`); Operator + Helm + per-cloud drivers; metering → billing.

## Parked — needs a human decision first
- Force-promote tenant self-service? (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017)
- Unit-economics model per tier (ADR-0008) · event catalog (ADR-0022; the boundary linter shipped
  in T-0002/T-0009)
- **Extraction-trigger budgets — ADR-0030 (Proposed).** Blocks T-0009 reaching Done.
- **A second GitHub org member.** GitHub forbids self-approval, so a required review plus
  `enforce_admins=true` makes merging impossible with one member — which is why T-0002 AC5 runs but
  does not block. Blocks EP-0 closing.
