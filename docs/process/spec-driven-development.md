# Spec-Driven Development (SDD)

**No feature code without an approved spec.** A spec is the single, testable description of
*what* a capability does; the ADRs constrain *how*; tests derive from the spec's acceptance
criteria.

## Spec vs ADR
- **ADR** = an architectural **decision** (SOT, `docs/adr/`). Rare, cross-cutting, immutable.
- **Spec** = a capability's **behavior** (`docs/specs/`). Per feature; evolves via PR.
- If writing a spec forces a new architectural decision → raise an ADR first.

## Lifecycle
`Draft` → (review) → `Approved` → (implemented) → `Implemented`. Specs are versioned in git;
change via PR. A task may not enter RED (tests) until its spec is `Approved`.

## What a spec contains (see `../specs/_template.md`)
- Context & problem; **in-scope / out-of-scope**.
- Contracts touched (`contracts/…`) and data owned (which context/schema — ADR-0022).
- **Acceptance criteria** written as testable statements (these become tests).
- Non-functional + **governance mapping** (which of G1–G9 apply and how).
- Open questions / assumptions.

## When a full spec isn't required
Pure chore/infra tasks (scaffolding, CI wiring, benchmarks) may use the task's
**acceptance criteria** directly instead of a separate spec — state that in the task.
Anything with user-visible or cross-context behavior needs a spec.
