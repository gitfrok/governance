# ADR-0015: UI/UX principle — GitHub-clean, with a unified security/compliance surface

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G3 supply-chain, G5 auditability, G6 compliance; product differentiation

## Context
GitLab's premium value is governance, but its UX is dense and fragmented across many
tabs; GitHub is clean but lacks Ultimate-depth governance. Our wedge is delivering deep
governance features through a clean, unified surface.

## Decision
Adopt GitHub-style UX principles — speed (sub-100ms interactions, optimistic UI),
keyboard-first (command palette), progressive disclosure, and strong defaults — and
**consolidate security, vulnerabilities, and compliance into one unified surface** rather
than scattering them. Establish a design system (tokens + components) so this is
enforced, not aspirational. This constrains how *every* feature surfaces its governance
data.

## Consequences
**Positive:** the differentiator (unified governance UX) is a first-class design rule;
consistent, fast product.
**Negative:** requires real design-system + frontend investment; the unified dashboard is
a cross-cutting integration point many features must feed.
**Follow-ups:** design-system foundation; the security dashboard's data contract.

## Alternatives considered
- **Mirror GitLab's per-feature tabs** — reproduces the fragmentation we're differentiating from.
- **GitHub parity without Ultimate depth** — no differentiation; just another Git host.
