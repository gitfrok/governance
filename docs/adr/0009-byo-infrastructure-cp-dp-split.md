# ADR-0009: BYO infrastructure via a control-plane / data-plane split (BYOC)

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G1 isolation, G6 compliance, G7 residency, G8 cost

## Context
Customers want their source and data in their own cloud; we want to escape the
variable-cost/abuse exposure of hosting the data plane.

## Decision
Split into a slim, multi-tenant **control plane** (we host: billing, org metadata,
policy authoring, dashboards, releases) and a **data plane** the customer runs in their
own Kubernetes (repos, CI, registry, scanners, data). Offer three topologies:
**C** BYO-runner (on-ramp), **B** full BYOC hybrid (flagship), **A** fully self-managed
/ air-gapped. Lead with B.

## Consequences
**Positive:** residency/isolation/compliance largely solved by architecture; flat-rate
de-risked (customer funds the heavy data plane); data-plane becomes single-tenant.
**Negative:** we now run software in environments we don't control (see ADR-0011);
support/test burden across clouds.
**Follow-ups:** agent security model; per-cloud conformance suite.

## Alternatives considered
- **Fully hosted only** — simplest for us, but loses residency-sensitive buyers and keeps cost risk.
- **Self-managed only** — heavy support, no SaaS convenience.
