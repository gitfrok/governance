# ADR-0006: Policy-as-code with OPA (PEP/PDP), deny-by-default

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G2 least privilege, G4 change governance, G6 compliance

## Context
Access rules, approval/merge rules, and compliance controls must be consistent,
versioned, reviewable, and enforceable at runtime and in CI.

## Decision
Express policy as code (OPA/Rego, or Cedar) evaluated at a PDP that the gateway and CI
admission (PEP) call on every sensitive action. Policies live in their own reviewed
repo owned by Security/Legal; **deny-by-default** (absence of an explicit allow = deny).

## Consequences
**Positive:** one enforcement path; auditable, testable policy; engineers can't silently
loosen rules.
**Negative:** a PDP call per request adds latency — mitigated by decision caching.
**Follow-ups:** policy test suite; bundle deployment pipeline.

## Alternatives considered
- **Hardcoded checks in app code** — inconsistent, unreviewable, easy to bypass.
