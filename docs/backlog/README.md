# Backlog — epics

Epics are grouped by roadmap phase and link down to executable tasks in `../tasks/`.
**Definition of Done** for every task: `../process/definition-of-done.md`.

## Phase 0 — Foundations
- **EP-0 Scaffolding & process**: T-0001 (repo layout), T-0002 (boundary/arch CI).
- **EP-1 Platform up**: T-0003 (Minikube dev env).
- **EP-2 Tenancy & governance base**: T-0004 (tenancy+RLS), T-0005 (PDP), T-0006 (audit log).
- **EP-3 Storage decision**: T-0007 (SeaweedFS-FUSE vs block-volume benchmark).

## Phase 1 — MVP
- **EP-4 Git plane**: T-0010 (Git-RPC), T-0011 (smart-HTTP+SSH), T-0012 (sync-replica+failover).
- **EP-5 Identity**: T-0013 (Zitadel + PATs, tenant scoping).
- **EP-6 Code UX**: T-0014 (repo read APIs + BFF), T-0015 (web browser/diff/palette).
- **EP-7 Review & CI**: T-0016 (MR + protected branches + approval policy), T-0017 (CI v0 gVisor+KEDA).

## Phase 2 — Ultimate wedge  *(to be expanded)*
Scanner integration; unified security dashboard; security/approval policies-as-code; audit
UI + evidence export; Zoekt search.

## Phase 3 — BYO  *(to be expanded)*
Agent impl (`contracts/proto/agent/v1`); Operator + Helm + per-cloud drivers; metering → billing.

## Parked — needs a human decision first
- Force-promote tenant self-service? (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017)
- Unit-economics model per tier (ADR-0008) · boundary linter + event catalog (ADR-0022)
