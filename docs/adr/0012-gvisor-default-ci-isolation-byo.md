# ADR-0012: gVisor (RuntimeClass) as the default CI isolation on BYO clusters

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G1 isolation
- **Refines:** ADR-0005

## Context
On managed node pools (GKE/EKS/AKS), Firecracker microVMs are hard — they need
KVM/nested virtualization, often bare-metal nodes. We still need per-job isolation
(ADR-0005) but portably.

## Decision
Default to **gVisor via `RuntimeClass`** (GKE Sandbox built-in; installable on EKS/AKS)
as the portable CI isolation runtime. Offer **Kata Containers** where customers require
VM-grade isolation and can supply capable node pools. Reserve Firecracker for our own
hosted fleet.

## Consequences
**Positive:** works across all three managed clouds without special node hardware.
**Negative:** some syscall/compatibility and performance caveats vs full VMs.
**Follow-ups:** document workloads that need Kata; per-cloud enablement steps.

## Alternatives considered
- **Require Firecracker everywhere** — not portable on managed node pools.
- **Plain containers** — insufficient isolation for untrusted code.
