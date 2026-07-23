# Architecture Decision Records (ADRs) — Source of Truth

This directory is the **single Source of Truth (SOT)** for the architecture of the
Git SaaS platform. Every architecturally-significant decision lives here as an ADR.
**If any diagram, wiki, slide, design doc, or comment disagrees with an Accepted ADR, the ADR wins.**

Narrative context lives in `docs/architecture/`; the shared contracts in `contracts/`; the *decisions* live here.

## Format
ADRs use the Nygard/MADR style: *Status, Context, Decision, Consequences, Alternatives*.
One decision per file. See [`0000-template.md`](0000-template.md).

## Statuses
`Proposed` → `Accepted` → (`Superseded by ADR-XXXX` | `Deprecated`)

## Process (our decision governance — see ADR-0001 & ADR-0002)
1. Copy `0000-template.md` to `NNNN-title.md` (next number).
2. Open a pull request — **the PR review is the decision-approval gate** (see the repo PR template).
3. On merge, set status to `Accepted`. ADRs are immutable once Accepted.
4. To change a decision, add a **new** ADR that supersedes the old one (mark the old one
   `Superseded by ADR-XXXX`). Never rewrite history.

## Index

| ADR | Decision | Status |
|-----|----------|--------|
| [ADR-0001](0001-adrs-as-source-of-truth.md) | ADRs are the Source of Truth | Accepted |
| [ADR-0002](0002-governance-driven-design.md) | Adopt Governance-Driven design | Accepted |
| [ADR-0003](0003-multitenancy-shared-db-rls-cells.md) | Multi-tenancy: shared DB + RLS + cells | Accepted |
| [ADR-0004](0004-git-storage-tier.md) | Git storage via Git-RPC over sharded nodes | Accepted |
| [ADR-0005](0005-ci-ephemeral-sandbox-isolation.md) | CI: ephemeral per-job sandbox isolation | Accepted |
| [ADR-0006](0006-policy-as-code-opa.md) | Policy-as-code with OPA (PEP/PDP) | Accepted |
| [ADR-0007](0007-append-only-audit-log.md) | Append-only, tamper-evident audit log | Accepted |
| [ADR-0008](0008-flat-rate-fair-use-cost-governance.md) | Flat-rate + fair-use cost governance | Accepted |
| [ADR-0009](0009-byo-infrastructure-cp-dp-split.md) | BYO infra: control/data-plane split (BYOC) | Accepted |
| [ADR-0010](0010-target-gke-eks-aks-portability.md) | Target GKE/EKS/AKS via portability layer | Accepted |
| [ADR-0011](0011-outbound-only-agent.md) | Outbound-only agent for CP↔DP | Accepted |
| [ADR-0012](0012-gvisor-default-ci-isolation-byo.md) | gVisor default CI isolation on BYO | Accepted |
| [ADR-0013](0013-helm-plus-operator-packaging.md) | Package via Helm + Operator | Accepted |
| [ADR-0014](0014-dedicated-code-search-index.md) | Dedicated code-search index (Zoekt-style) | Accepted |
| [ADR-0015](0015-uiux-github-clean-unified-security.md) | UI/UX: GitHub-clean + unified security surface | Accepted |
| [ADR-0016](0016-git-failover-sync-one-replica.md) | Git failover: sync 1 replica + async fan-out | Accepted |
| [ADR-0017](0017-agent-grpc-mtls-protocol.md) | Agent protocol: gRPC streaming over mTLS | Accepted |
| [ADR-0018](0018-dual-loss-failover-policy.md) | Dual-loss failover: fail-safe (halt + audited override) | Accepted |
| [ADR-0019](0019-technology-stack.md) | Technology stack (v1) | Superseded by ADR-0020 |
| [ADR-0020](0020-technology-stack-rev2.md) | Technology stack rev.2 (Astro SSR, Redpanda, SeaweedFS) | Superseded by ADR-0023 |
| [ADR-0021](0021-local-dev-orbstack.md) | Local/dev: OrbStack + *.orb.local | Superseded by ADR-0024 |
| [ADR-0022](0022-high-cohesion-low-coupling.md) | Modular architecture: high cohesion, low coupling | Accepted |
| [ADR-0023](0023-technology-stack-rev3.md) | Technology stack rev.3 (version floors + Valkey) | Accepted |
| [ADR-0024](0024-local-dev-minikube.md) | Local/dev: Minikube only + *.gitsaas.test | Accepted |
| [ADR-0025](0025-modular-monolith.md) | Modular monolith (one app binary per plane) | Accepted |
| [ADR-0026](0026-service-based-target.md) | Target architecture: service-based (coarse services) | Accepted |
| [ADR-0027](0027-repo-topology-submodules.md) | Multi-repo source topology via git submodules | Accepted |
| [ADR-0028](0028-agdd-framework.md) | AGDD — AI-Agent Governance-Driven Development framework | Accepted |

## Open follow-ups (tracked *inside* ADRs; promote to new ADRs when decided)
- CI job asserting installed versions meet the floors — ADR-0023
- `make dev-up` Minikube bootstrap + per-OS driver docs — ADR-0024
- Boundary-enforcement linter + event catalog/naming — ADR-0022 (co-located vs separate app-contexts resolved by ADR-0025)
- Track & act on service-extraction triggers (fitness functions) — ADR-0026
- Super-repo CI: fail on submodule pointers referencing unmerged commits — ADR-0027
- Per-repo scaffolding + generated-type publishing (contracts → TS) — ADR-0027/0028
- Repo backing: SeaweedFS-FUSE vs block volumes — benchmark, may amend ADR-0016 — ADR-0020/0023
- Replica selection + fencing; force-promote runbook/authz + tenant self-service? — ADR-0018/0016
- Cert issuance/rotation (SPIFFE/SPIRE) + HTTP-2 proxy fallback — ADR-0017
- Unit-economics model per pricing tier — ADR-0008
