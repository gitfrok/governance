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

## Phase 2 — the Ultimate wedge · **Complete (2026-08-14)**

Security scanners → normalized findings → **unified dashboard**; security/approval policies as code;
audit trail + evidence pack export under scoped auditor grants; permission-filtered code search.

**Exit (met):** the differentiating governance/security surface runs end to end. Every scenario step
was executed against live scanners, the real BFF → PDP → Rego path, and live pack/grant proofs — the
evidence mapping is in `../plans/phase-2-ultimate-wedge.md`. Epics **EP-11…EP-14** closed; tasks
**T-0022…T-0028** all Done against **SPEC-0024…SPEC-0035**; **ADR-0055** (Accepted) settled audit
retention, closing ADR-0007's follow-up and SPEC-0011's last open item. T-0018's AC19 — an evidence
pack carries zero attested records in its control sections (ADR-0029 §4, SPEC-0011 AC14) — was
carried verbatim as T-0026 AC2 and proven live.

Three review waves followed the exit and are recorded in the plan: seventeen findings (H1–L17), then
seven on the fixes themselves (N1–N7), then the two residuals. The code that came out of them is
pinned at backend `90bf1a1` / super-repo `086c965`.

**Two deployment-posture limits are carried, not closed** — both recorded in the plan with
follow-ups, and both bounded by the single-tenant dev posture the phase ships under:

- **(d) the dataplane gRPC door is unauthenticated**, so every Phase-2 RPC takes tenant, actor and
  roles off the wire and the PDP decides correctly about a caller-asserted subject. Security rests on
  network isolation of that port plus RLS as the backstop. H1's tenant guard on the decision-record
  reads is implemented and tested but degenerates to a consistency check until a tenant-pinning
  interceptor gives it a verified caller. Recorded in SPEC-0002's open questions.
- **(e) Phase-2 in-process state does not survive a restart** — the attribution projection, pack
  assembly state and the code-search index — and the index has no per-tenant or global cap. Recorded
  against SPEC-0031 AC8 and SPEC-0034 AC4/AC5.

Also carried: the PDP-driven merge-gate severity threshold and the two new gap-reason wire enums,
both additive contract changes tracked in `../backlog/`.

## Phase 3 — BYO · **Active (2026-08-14)**

Agent (implements `contracts/proto/agent/v1`), Operator + Helm, per-cloud drivers, usage metering →
billing + fair-use.
**Exit:** a customer runs the data plane in their own GKE/EKS/AKS under a flat plan.

Plan: `../plans/phase-3-byo.md`. Scope PR-20…PR-23 as epics **EP-15…EP-18**, tasks **T-0030…T-0034**,
specs **SPEC-0038…SPEC-0041** (all Draft — Approved before RED). The architecture was decided in
Phase 0/1 (ADR-0009/0010/0011/0013/0017); the two decisions that were open are settled by **ADR-0060**
(one-time enrolment token, control-plane-issued short-lived certificates — closing ADR-0017's
cert-issuance follow-up) and **ADR-0061** (the control plane is the metering authority; a customer's
cluster never reports the number it is measured against).

**Still open, and able to block an install outright:** proxy-only egress — the remaining half of
ADR-0017's follow-up. A customer whose egress permits only an HTTP proxy cannot install today.

## Architecture evolution (ADR-0025 → ADR-0026)

Phases 0–3 ship as a **modular monolith per plane** (ADR-0025). A module becomes its own **coarse
service** (ADR-0026) only when a fitness-function trigger fires — distinct scaling profile,
isolation/blast-radius/compliance need, divergent SLO/deploy-cadence/ownership, or build/test/deploy
time crossing the ADR-0030 budget. Under BYO each extraction adds a pod to the customer's cluster, so
it must justify the footprint (G8). Triggers are measured (T-0009), not scheduled.

## Later / not scheduled

Registry hardening, packages, air-gapped installs (Topology A), advanced compliance frameworks.
