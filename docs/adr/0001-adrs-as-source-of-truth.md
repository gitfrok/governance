# ADR-0001: Architecture Decision Records are the Source of Truth

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G4 change governance, G5 auditability

## Context
Design context is spread across docs and people's heads. In a governance-driven
system we need architectural decisions to be traceable, reviewable, and durable —
decisions themselves must be governed.

## Decision
We will record every architecturally-significant decision as an ADR in
`docs/adr/`, one file per decision, in Nygard/MADR format. **These ADRs are the
single Source of Truth (SOT).** If a diagram, wiki, or slide disagrees with an
accepted ADR, the ADR wins. New ADRs are added by copying `0000-template.md`,
incrementing the number, and merging via pull request (the PR review *is* the
decision-approval gate). ADRs are immutable once Accepted; to change a decision we
add a new ADR that supersedes the old one (old one marked `Superseded by ADR-XXXX`).

## Consequences
**Positive:** durable rationale; onboarding is faster; audit-ready decision trail;
decisions get real review.
**Negative:** discipline required — an un-recorded decision is treated as not yet made.
**Follow-ups:** wire an ADR checklist into the PR template.

## Alternatives considered
- **Wiki/Confluence pages** — mutable, no review gate, drifts from code.
- **Decisions live only in code/PRs** — rationale gets lost.
