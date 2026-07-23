# ADR-0013: Package and manage lifecycle via a Helm chart + Kubernetes Operator

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** operability, G4 change governance

## Context
The data plane must install and stay healthy across many customer clusters, at
different versions, including air-gapped ones.

## Decision
Ship a **Helm chart** for install/config and a **Kubernetes Operator (CRDs)** for
day-2: reconciliation, self-healing, and controlled, customer-approved upgrades. Support
an **air-gapped** mode (mirrored images + offline license).

## Consequences
**Positive:** declarative, self-healing installs; safe upgrade orchestration at fleet scale.
**Negative:** an operator is real software to build, test, and version across clouds.
**Follow-ups:** CRD spec + default Helm values; upgrade/rollback strategy.

## Alternatives considered
- **Raw manifests / install scripts** — no reconciliation, painful upgrades at scale.
