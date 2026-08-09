# Roadmap

Milestone-based; each phase has an **exit criterion** before the next begins. Detailed
execution lives in `../plans/`; work items in `../backlog/` and `../tasks/`.

## Phase 0 — Foundations
Scaffolding, dev environment, tenancy + RLS, PDP, audit log, and the **storage benchmark**
that unblocks the git-storage design.
**Status:** **Complete (2026-08-09).**
**Exit (met):** an empty-but-wired foundation: a Minikube environment with real TLS;
tenant-scoping, deny-by-default policy, and append-only audit seams; the storage decision;
and boundary, architecture, contract, policy/isolation, and fitness gates enforced in CI.

The end-to-end policy-checked request is a Phase-1 deployment milestone. It requires the
plane images owned by T-0021, which is correctly scoped to Phase 1; it is not a Phase-0
exit criterion.

## Phase 1 — MVP (GitHub-lite)
Git push/pull (RPC + sync-replica write path), auth (Zitadel), repo/file/diff UI, MR/PR
review with protected branches, CI v0 (gVisor sandboxes), and the **container images** that make any
of it deployable.
**Exit:** a team can host a repo, open/review/merge an MR, and run a pipeline.
(Tasks T-0010–T-0018, T-0021.)

T-0021 (images) is new and sits under the others: nothing in the four repos builds a container image
yet, so no plane has ever run as a deployed artifact. Its AC0 — an ADR for the image build surface —
is **met: ADR-0035, Accepted 2026-08-08**, so the task is unblocked and AC1–AC6 are ready to start.

Its images enable the Phase-1 end-to-end deployment milestone: a policy-checked request in
Minikube. Phase 0 completed on 2026-08-09 with its foundation scope; T-0021 remains correctly
scoped to Phase 1.

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
