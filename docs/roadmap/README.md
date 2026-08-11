# Roadmap

Milestone-based; each phase has an **exit criterion** before the next begins. Execution detail is in
`../plans/`, work items in `../backlog/` and `../tasks/`.

## Phase 0 — Foundations · **Complete (2026-08-09)**

Scaffolding, dev environment, tenancy + RLS, PDP, audit log, and the storage benchmark that unblocked
the git-storage design.

**Exit (met):** an empty-but-wired foundation — Minikube with real TLS; tenant-scoping, deny-by-default
policy and append-only audit seams; the storage decision (ADR-0033); boundary, architecture, contract,
policy/isolation and fitness gates enforced in CI.

## Phase 1 — MVP (GitHub-lite) · **Complete (2026-08-11)**

Git push/pull (RPC + sync-replica write path), auth (Zitadel), repo/file/diff UI, MR review with
protected branches, CI v0 (gVisor sandboxes), and the container images that make any of it deployable.

**Exit (met):** a team can host a repo, open/review/merge an MR, and run a pipeline. Tasks T-0010–T-0018
and T-0021 all Done; the code-driven half of the end-to-end scenario executed live 2026-08-11.

Two of the scenario's steps are *demonstrable* only on T-0003's cluster lane, recorded as host limits
rather than open code: CI dispatch needs a gVisor RuntimeClass no rootless-podman driver provides
(T-0017), and the durability-quorum/failover demonstration needs a second physical node (T-0012 and
T-0018 both prove it in their suites). Detail: `../plans/phase-1-mvp.md`.

## Phase 2 — the Ultimate wedge · **next**

Security scanners → normalized findings → **unified dashboard**; security/approval policies as code;
audit UI + evidence export; code search.
**Exit:** the differentiating governance/security surface is usable end-to-end.

No plan file, epics or tasks exist yet, so the first move is a plan under `../plans/`. It inherits
T-0018's AC19 — an evidence pack must carry zero attested records in its control sections (ADR-0029 §4,
SPEC-0011 AC14).

## Phase 3 — BYO

Agent (implements `contracts/proto/agent/v1`), Operator + Helm, per-cloud drivers, usage metering →
billing + fair-use.
**Exit:** a customer runs the data plane in their own GKE/EKS/AKS under a flat plan.

## Architecture evolution (ADR-0025 → ADR-0026)

Phases 0–3 ship as a **modular monolith per plane** (ADR-0025). A module becomes its own **coarse
service** (ADR-0026) only when a fitness-function trigger fires — distinct scaling profile,
isolation/blast-radius/compliance need, divergent SLO/deploy-cadence/ownership, or build/test/deploy
time crossing the ADR-0030 budget. Under BYO each extraction adds a pod to the customer's cluster, so
it must justify the footprint (G8). Triggers are measured (T-0009), not scheduled.

## Later / not scheduled

Registry hardening, packages, air-gapped installs (Topology A), advanced compliance frameworks.
