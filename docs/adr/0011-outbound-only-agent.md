# ADR-0011: Outbound-only agent for control-plane ↔ data-plane connectivity

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G9 least-privilege footprint, security

## Context
In BYOC (ADR-0009) we must reach the customer's cluster without opening inbound holes
in their network, and without exfiltrating their code.

## Decision
The customer installs a lightweight **agent** that opens an **outbound-only** TLS
connection to our control plane. It registers the cluster, reports health/telemetry
and billing metadata, and pulls **desired state** (versions/components) to reconcile.
Source code and secrets never traverse it. The agent runs least-privilege, and its
RBAC + network policy are **published** so customer security teams can verify it.

## Consequences
**Positive:** no inbound firewall changes; strong trust story; auditable footprint.
**Negative:** reduced direct observability — rely on agent telemetry.
**Follow-ups:** agent protocol spec; supply-chain signing of the agent.

## Alternatives considered
- **Inbound API / VPC peering / VPN** — requires opening customer networks; higher friction and risk.
