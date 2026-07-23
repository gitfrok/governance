# ADR-0002: Adopt Governance-Driven design (policy-as-code, PEP/PDP, traceability)

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** all objectives (G1–G9)

## Context
The product is a GitLab-Ultimate-class platform whose premium value *is* governance
(audit, compliance, approval policies, security). Governance is both our operating
discipline and our flagship feature, so it should drive the architecture rather than
be bolted on.

## Decision
We will derive the architecture from an explicit governance model. Every component
traces to a governance objective; policy is expressed **as code** and enforced at a
Policy Enforcement Point (PEP) that consults a Policy Decision Point (PDP), with
deny-by-default. Enforcement spans design-time, build-time (CI), deploy-time (CD),
and run-time.

## Consequences
**Positive:** compliance is provable; the flagship feature and the platform share one
model; clear traceability.
**Negative:** more upfront modeling; a policy engine to own and test.
**Follow-ups:** maintain the governance-objective → requirement traceability table.

## Alternatives considered
- **Add controls after building features** — the usual path; produces gaps and rework.
