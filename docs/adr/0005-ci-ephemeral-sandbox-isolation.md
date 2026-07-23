# ADR-0005: CI/CD runs each job in an ephemeral, strongly-isolated sandbox

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G1 isolation, security

## Context
CI runners execute arbitrary, untrusted user code. This is a security boundary, and
(in hosted mode) the largest cost center and abuse target.

## Decision
Run **one ephemeral sandbox per job**, destroyed after completion, using VM-grade
isolation (microVM / gVisor / Kata — see ADR-0012 for the BYO default). Never run two
tenants' code in one shared sandbox. Runners autoscale off a queue and scale to zero.

## Consequences
**Positive:** contains hostile builds; clean per-job teardown.
**Negative:** cold-start latency and compute cost — managed via caching and scale-to-zero.
**Follow-ups:** cost governance quotas (ADR-0008); abuse detection.

## Alternatives considered
- **Shared containers/runners** — cheaper but an unacceptable isolation risk.
