# ADR-0007: Append-only, tamper-evident audit log

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G5 auditability, G6 compliance

## Context
Audit is both a compliance requirement and a flagship product feature; it must be
trustworthy as evidence.

## Decision
Maintain a dedicated **append-only** audit log, **hash-chained** (tamper-evident), with
**no delete/update API**, stored separately from operational logs. Compliance evidence
exports are generated from it.

## Consequences
**Positive:** trustworthy evidence; supports SOC2/ISO/HIPAA exports.
**Negative:** storage growth; needs retention/archival strategy.
**Follow-ups:** evidence-export tooling; retention policy per framework.

## Alternatives considered
- **Standard app logs / mutable DB table** — not trustworthy as audit evidence.
