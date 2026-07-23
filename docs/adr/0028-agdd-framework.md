# ADR-0028: Adopt AGDD — AI-Agent Governance-Driven Development — as the delivery framework

- **Status:** Accepted
- **Date:** 2026-07-21
- **Relates to:** ADR-0002 (governance-driven design), ADR-0001 (ADR SoT), ADR-0027 (repo topology)

## Context
Development is done primarily by AI coding agents (Claude Code, Codex, OpenCode). We need a
framework that lets agents move fast **without** drifting from architecture, security, or
compliance intent.

## Decision
Adopt **AGDD**: agents deliver software under **machine-enforced governance**, where the
**governance repo is the control surface**. Full guide: `../process/agdd.md`.

**Pillars**
1. **Governance-as-code** — objectives **G1–G9**, ADRs (SoT), specs, invariants, and
   policies-as-code all live, versioned, in the **governance** repo (ADR-0027).
2. **Agentic SDLC** — the loop in `../process/agentic-sdlc.md` (pick task → ensure spec →
   RED/GREEN/REFACTOR → gates → PR → human decision gate).
3. **Spec-driven + TDD** — no feature code without an approved spec; tests precede code.
4. **Enforced boundaries** — HCLC (ADR-0022), modular monolith (ADR-0025), and the submodule
   dependency direction (ADR-0027) are checked by **fitness functions** + CI, not trust.
5. **Human-in-the-loop gates** — new decisions become **Proposed ADRs**; specs need approval;
   super-repo submodule-pointer bumps are reviewed.

**Operating rule:** agents read governance **first** (it is the "policy brain"); code repos are
"actuators." An agent may not decide governance silently — it drafts an ADR/spec and stops.

## Consequences
**Positive:** speed with guardrails; every change is traceable to an objective/decision/spec;
auditable by construction (aligns with G5/G6).
**Negative:** more up-front artifacts (specs/ADRs) and process discipline; mitigated by templates
and the fact that the artifacts are the enforcement, not paperwork.

## Alternatives considered
- **Unconstrained agentic coding** — rejected: drifts from architecture/security intent.
- **Heavy human process only** — rejected: doesn't scale to agent throughput.
