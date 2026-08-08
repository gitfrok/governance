{{include:banner}}
# CLAUDE.md (super-repo)

**Read `AGENTS.md` (this repo) then `governance/AGENTS.md` first.** Governance is the SoT.

- Determine the target submodule from the task's `Repo(s):` field; work inside that repo; never
  span two submodules in one commit (ADR-0027, invariants 21–25).
- Follow AGDD: spec-first, TDD, boundaries enforced by fitness functions + CI.
- New decision → Proposed ADR in `governance/` and stop. API change → governance PR first.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
