# Roadmap

Milestone-based; each phase has an **exit criterion** before the next begins. Detailed
execution lives in `../plans/`; work items in `../backlog/` and `../tasks/`.

## Phase 0 — Foundations
Scaffolding, dev environment, tenancy + RLS, PDP, audit log, and the **storage benchmark**
that unblocks the git-storage design.
**Exit:** an empty-but-wired repo where a tenant-scoped, policy-checked, audited request
runs end-to-end in Minikube; boundary/arch tests enforced in CI; benchmark decided.

## Phase 1 — MVP (GitHub-lite)
Git push/pull (RPC + sync-replica write path), auth (Zitadel), repo/file/diff UI, MR/PR
review with protected branches, CI v0 (gVisor sandboxes).
**Exit:** a team can host a repo, open/review/merge an MR, and run a pipeline. (Tasks T-0010–T-0017.)

## Phase 2 — the Ultimate wedge
Security scanners → normalized findings → **unified dashboard**; security/approval policies
as code; audit UI + evidence export; code search.
**Exit:** the differentiating governance/security surface is usable end-to-end.

## Phase 3 — BYO
Agent (implements `contracts/proto/agent/v1`), Operator + Helm, per-cloud drivers, usage
metering → billing + fair-use.
**Exit:** a customer runs the data plane in their own GKE/EKS/AKS under a flat plan.

## Architecture evolution (ADR-0025 → ADR-0026)
Phases 0–3 ship as a **modular monolith per plane** (ADR-0025). A module is extracted into its own
**coarse service** (ADR-0026) only when a fitness-function trigger fires — distinct scaling profile,
isolation/blast-radius/compliance need, divergent SLO/deploy-cadence/ownership, or the monolith's
build/test/deploy time crossing budget. Under BYO each extraction adds a pod to the customer's
cluster, so it must justify the footprint (G8). Triggers are tracked (T-0009), not scheduled.

## Later / not scheduled
Registry hardening, packages, air-gapped installs (Topology A), advanced compliance frameworks.
