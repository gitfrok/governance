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
review with protected branches, CI v0 (gVisor sandboxes), and the **container images** that make any
of it deployable.
**Exit:** a team can host a repo, open/review/merge an MR, and run a pipeline.
(Tasks T-0010–T-0018, T-0021.)

T-0021 (images) is new and sits under the others: nothing in the four repos builds a container image
yet, so no plane has ever run as a deployed artifact. It is **blocked on its own AC0** — a Proposed
ADR for the image build surface, which no Accepted ADR covers. It also **conflicts with Phase 0's
exit criterion as written**, since that criterion needs an end-to-end request in Minikube and this is
what makes one possible; see the open questions in `../tasks/T-0021-container-images.md`, which
records the three ways out rather than picking one.

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
