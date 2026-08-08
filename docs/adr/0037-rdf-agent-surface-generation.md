# ADR-0037: Adopt RDF's canonical-first agent surface — generated from governance, not a second governance

- **Status:** Proposed
- **Date:** 2026-08-08
- **Deciders:** platform
- **Governs:** G7 process integrity — the files that steer our agents are currently the only
  governance artifacts in the tree that nothing checks
- **Relates to:** **ADR-0028** (AGDD — *refined, not superseded*) · ADR-0027 (repo topology) ·
  ADR-0002 (governance-driven design) · ADR-0001 (ADR SoT) ·
  **Invariants:** 11, 12, 21, 23 · **Upstream:** [rfxn/rdf](https://github.com/rfxn/rdf) (GPL v2)

## Context

ADR-0028 made governance the control surface and code repos the actuators. It did not say how the
*agent-facing* files get written. In practice they are hand-maintained, and there are sixteen of them:

```
super-repo   AGENTS.md  CLAUDE.md  opencode.json  .cursor/rules/agdd.mdc
governance   AGENTS.md  CLAUDE.md  opencode.json
backend      AGENTS.md  CLAUDE.md  opencode.json
bff          AGENTS.md  CLAUDE.md  opencode.json
webfrontend  AGENTS.md  CLAUDE.md  opencode.json
```

Every one of them restates the same rules — dependency direction, the submodule boundary, spec-first,
TDD, "governance is SoT" — in a slightly different voice for a slightly different runtime. Nothing
checks that they agree with each other or with `docs/agents/invariants.md`. When invariant 7 was
rewritten after T-0007 and ADR-0033, five `CLAUDE.md` files kept whatever they said before. This is
the same class of defect ADR-0034 and ADR-0036 were written about: a rule that nothing verifies is a
rule that drifts, and we only notice when it has already cost a run.

We already solved this shape once for generated code. `scripts/check-codegen-fresh.sh` regenerates
from `contracts/` and fails CI on a diff, so generated Go and TS cannot drift from the proto. The
agent surface has no equivalent, and it is arguably the higher-leverage of the two — it is what an
agent reads *before* it writes anything.

**RDF** (rfxn Development Framework) is an external, production-used framework that solves exactly
this. Its architecture, stripped to the part that matters here:

- **Canonical-first, adapter-delivered.** Tool-agnostic markdown lives in one `canonical/` tree;
  per-tool adapters generate Claude Code, Codex, Antigravity, `AGENTS.md`, and Agent-Skills output.
  Write once, emit six surfaces.
- **Six typed agent personas** — planner, dispatcher, engineer, QA, reviewer, UAT — whose behaviour
  is shaped by per-project governance files rather than baked-in prompts. We commit **zero** agent
  personas today.
- **Drift detection.** `rdf doctor --scope content-drift` compares deployed output against canonical
  via per-file `.rdf-hash` sidecars; `rdf sync` pulls emergency edits back.
- **Modes** — seven session-scoped methodology overlays (security, performance, migration,
  refactoring, debugging, documentation, development) that change how agents think without editing
  governance.
- **Scale-adaptive ceremony** — `--full` / `--quick` / `--bugfix` tiers, where lighter tiers remove
  ceremony but never remove the security review.

Its stack profiles cover ours: `go`, `typescript`, `frontend`, `database`, `infrastructure`.

**But RDF also carries a governance model of its own, and that half collides with ours.** `rdf init`
scaffolds `.rdf/governance/{conventions,constraints,verification,anti-patterns,architecture}.md`
*inside each project*, and adds `CLAUDE.md`, `PLAN*.md`, and `.rdf/` to `.git/info/exclude` so they
are never committed. Adopting that as written would give us a second, uncommitted, unreviewed source
of engineering rules in every repo — which invariant 21 forbids outright, and which ADR-0001 would
make ambiguous the first time it disagreed with an ADR.

One more thing needs saying because the branch this work started on is named for it: **`rdf migrate`
does not perform the migration this ADR is about.** That subcommand moves `.claude/governance/` and
`work-output/` into `.rdf/`. We have neither, so on any repo here it takes the `EC10` path and exits
`2` — *"fresh project — use `rdf init` instead"*. The migration that matters is a different one:
sixteen hand-written files becoming generated output with a freshness gate.

## Decision

We will adopt **RDF's method — canonical-first, adapter-delivered, drift-gated — and reject RDF's
per-project governance scaffolding.** `governance/` remains the single canonical source; RDF becomes
the generator that turns it into per-runtime surfaces.

1. **`governance/` is canonical; agent surfaces become generated output.** The sixteen files above
   stop being hand-edited and become adapter output from a single canonical tree in this repo. A rule
   is written once, next to the invariant it implements, and every runtime gets it.

2. **`rdf init`'s governance scaffolding is not adopted, in any repo.** No `.rdf/governance/`, no
   per-project `conventions.md` / `constraints.md` / `anti-patterns.md`. Invariant 21 is unchanged:
   ADRs, specs, invariants, `contracts/`, and `policies/` change only here. RDF's profiles are used
   as *input* when authoring canonical content, never as a parallel rule store.

3. **Generated surfaces are committed and gated, not excluded.** RDF's `.git/info/exclude` model is
   inverted: we commit the output and add `scripts/check-agent-surfaces-fresh.sh`, modelled on the
   existing `check-codegen-fresh.sh`, that regenerates and fails CI on any diff. Drift becomes a red
   build, exactly as it already is for `contracts/` codegen. `rdf doctor --scope content-drift` and
   `.rdf-hash` sidecars are the local fast path; CI is the gate.

4. **RDF is consumed as an external tool, not vendored.** It is installed and pinned by commit,
   invoked by our scripts. Nothing from `rfxn/rdf` is copied into these repos under this ADR.
   This is a licensing decision as much as an operational one: RDF is **GPL v2** and neither this
   repo nor the super-repo currently carries a `LICENSE` file. Vendoring `canonical/` prose or
   `lib/*.sh` would raise a derivative-work question we have not answered, and answering it is not
   this ADR's business. **Vendoring requires its own ADR.**

5. **Six typed personas are adopted; the dispatcher's execution model is not — yet.** Personas
   (planner, engineer, QA, reviewer, UAT) are additive and land in phase 1. The **dispatcher** drives
   parallel worktree builds behind a pre-commit hook that enforces a *plan-phase* boundary; it knows
   nothing about invariant 23 (one commit never spans two submodules). Adopting it requires teaching
   that hook our topology, and that is deferred to its own task with its own spec.

6. **GitHub Issues + Projects v2 is not adopted.** Work tracking stays `docs/roadmap/` →
   `docs/backlog/` → `docs/tasks/T-####.md`. RDF's issue hierarchy is a genuine alternative, but
   swapping the task system is unrelated to fixing surface drift and would be decided separately.

7. **Modes and scale-adaptive ceremony need a spec before adoption.** Both are attractive — a
   one-line fix currently pays the same spec-and-ADR ceremony as a subsystem — but ceremony tiers
   change *when a spec is required*, and that is an AGDD non-negotiable (`docs/process/agdd.md`).
   Phase 3 writes that spec; nothing about tiers is decided here beyond the intent to evaluate them.

### Migration, in phases

Each phase is a task with its own spec and PR; phases land in order.

| Phase | Scope | Gate |
|-------|-------|------|
| **0** | This ADR. | PR review. |
| **1** | Six personas authored in governance, generated into each repo's `.claude/agents/`. Additive — no existing file changes. | Regeneration is clean in CI. |
| **2** | The sixteen surfaces move to generated output from canonical governance. | `check-agent-surfaces-fresh.sh` required in governance + super-repo CI. |
| **3** | Spec for modes + ceremony tiers; adopt only what the spec justifies. | Spec approval. |
| **4** | Deferred, each needing its own ADR: dispatcher/worktree execution, GitHub Projects, vendoring. | — |

Phase 2 is the only phase that touches all five repos. It follows ADR-0027's ordered cross-repo
workflow: governance PR first, then each consumer, then the super-repo pointer bump — never one
commit spanning two submodules (invariant 23).

## Consequences

**Positive.** The rules an agent reads are generated from the invariants they implement, so invariant
7 changing once cannot leave five `CLAUDE.md` files behind. A new runtime costs an adapter, not five
more hand-written files. We gain six committed, reviewable agent personas where we have none, and the
agent surface gets the same freshness gate that `contracts/` codegen has had since T-0020. The
canonical/adapter split is proven upstream rather than invented here.

**Negative / costs.** We take a build-time dependency on a third-party framework for a surface that
currently needs no tooling at all — an `rdf generate` that breaks is a blocked PR, and upstream sets
its own release cadence. Editing an agent surface stops being "edit the file" and becomes "edit
canonical, regenerate, commit both", which is friction on exactly the files people edit casually;
this is the same friction `check-codegen-fresh.sh` already imposes, and the same argument justifies
it. We are also deliberately adopting half a framework: `rdf doctor` checks and RDF documentation
assume the `.rdf/governance/` layout that decision 2 rejects, so some upstream checks will not apply
and upstream docs will read as if they disagree with our tree. And the GPL v2 question is deferred,
not answered — it becomes blocking the moment anyone proposes vendoring.

**Follow-ups.**
- Neither this repo nor the super-repo has a `LICENSE`. That is independently worth fixing and
  becomes a prerequisite for any vendoring decision.
- The dispatcher's pre-commit boundary hook and invariant 23 are the same idea at different scopes;
  if phase 4 proceeds, they should be one mechanism, not two.
- RDF pins itself by release. Which commit we pin, and who bumps it, is phase 1's business — the
  super-repo already has the pattern for pinning by commit (invariant 25).

## Alternatives considered

- **Adopt RDF wholesale, including `/r-init` governance scaffolding** — rejected. It creates a
  second, uncommitted source of engineering rules in every repo, which invariant 21 forbids and
  ADR-0001 makes incoherent the first time it contradicts an ADR. The value we want is the
  canonical/adapter pipeline, and that part is separable.
- **Build our own generator instead of depending on RDF** — rejected as cost, not merit. It is a
  couple of hundred lines of shell we would then own, maintain, and test, to reproduce something that
  exists and is in production use. Worth revisiting only if the GPL question or upstream cadence
  turns the dependency sour; the canonical content is ours either way, so switching generators later
  is a contained change.
- **Vendor RDF's `canonical/` and adapters into governance** — rejected *here*, deferred to its own
  ADR. It removes the upstream-cadence risk and is the natural end state, but it is a GPL v2
  derivative-work question against repos with no `LICENSE` file, and that must be answered
  deliberately rather than as a side effect of a tooling change.
- **Do nothing; keep hand-maintaining sixteen files** — rejected. It is the status quo that already
  let five `CLAUDE.md` files drift past an invariant rewrite, and the cost grows with every repo and
  every runtime.
- **Run `rdf migrate` and treat that as the migration** — not available. It migrates
  `.claude/governance/` + `work-output/` → `.rdf/`, neither of which exists here; it exits `2`
  ("fresh project — use `rdf init` instead") on every repo in this tree. Naming it is worthwhile
  because the branch this work began on implies otherwise.
