# AGDD — AI-Agent Governance-Driven Development (the framework)

See ADR-0028. AGDD = deliver software with AI agents under **machine-enforced governance**,
where the **governance repo is the control surface**.

## The model
- **Policy brain:** the `governance` repo — G1–G9 objectives, ADRs (SoT), specs, invariants,
  `contracts/`, `policies/` (OPA/Rego). Versioned; changed only via reviewed PRs.
- **Actuators:** `backend`, `bff`, `webfrontend` — implement against governance, never around it.
- **Enforcement:** fitness functions + CI gates + PR checklists + Go `internal/` + submodule
  dependency direction. Guardrails are code, not trust.
- **Human gates:** Proposed ADRs (new decisions), spec approval, super-repo pointer bumps.

## The loop (per task) — details in `agentic-sdlc.md`
1. Read governance first (context → invariants → this framework → the task's spec + ADRs).
2. Confirm **which submodule** you are in; do not cross repo boundaries in one commit.
3. Ensure an approved **spec** (or write one). New decision needed → **Proposed ADR, stop**.
4. **TDD**: failing tests from acceptance criteria → minimal code → refactor within boundaries.
5. Run gates: unit + contract + integration + boundary/arch + policy/isolation + fitness + version-floor.
6. PR in the submodule (governance checklists). Cross-repo? follow the ordered workflow (ADR-0027).
7. Update task + backlog status. Merge is the decision gate.

## Non-negotiables
- Governance changes (ADR/spec/invariant/contract/policy) happen **only** in the governance repo.
- Additive-only contracts within v1. Deny-by-default policy. Everything traces to G1–G9.
