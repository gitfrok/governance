- The Source of Truth is the **governance** repo: `{{GOV}}/docs/` (ADRs, specs,
  invariants, contracts, policies). Read `{{GOV}}/AGENTS.md` before coding.
- Follow **AGDD** (`{{GOV}}/docs/process/agdd.md`): confirm your target repo, ensure an
  approved spec, write failing tests, implement, refactor within boundaries, pass CI gates, PR.
- Obey invariants 1–25 (`{{GOV}}/docs/agents/invariants.md`). New decision → Proposed
  ADR in governance and stop. API change → governance PR first (additive), then bump the pin.
- Keep diffs focused; never span two submodules in one commit.
