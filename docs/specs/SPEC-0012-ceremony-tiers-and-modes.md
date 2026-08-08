# SPEC-0012: Ceremony tiers & session modes

- **Status:** Proposed
- **Owner:** platform
- **Context(s):** process (governance only — no runtime code)
- **ADRs:** 0037 (decision 7 requires this spec before anything is adopted), 0039 (the flow this
  extends), 0028 (AGDD), 0001 (ADR SoT)
- **Task(s):** —

## Problem / context

AGDD applies one weight of ceremony to every change. A one-line typo fix in a comment and a new
tenant-isolation subsystem both nominally require an approved spec, tests written first, the full
gate set, and a PR against the definition of done. In practice people do not pay full ceremony for a
typo — they skip, and the skipping is undocumented, so nobody knows which parts were skipped or
whether skipping was reasonable.

That is worse than a written-down lighter tier, because an undocumented exception is indistinguishable
from a violation after the fact. The evidence is in this repo's own history: several merged changes
cite no spec because no spec would have been meaningful, and the record cannot tell those apart from
changes that should have had one.

ADR-0037 decision 7 flagged the second half of the problem and is the reason this is a spec rather
than a patch:

> ceremony tiers change *when a spec is required*, and that is an AGDD non-negotiable.

A mechanism that can waive the spec requirement must itself be specified and approved, or it is a
back door.

**Modes** are the smaller, separable half: session-scoped overlays (security, performance,
refactoring, debugging, documentation, migration) that change what an agent *emphasises* without
changing what is *required* of it. They are safe in a way tiers are not, and this spec keeps them
distinct for exactly that reason.

## In scope

- Three ceremony tiers — `full`, `quick`, `bugfix` — with the entry conditions for each stated as
  facts about the diff, not as judgement calls.
- The rule that no tier removes a **security-relevant** gate, and a definition of security-relevant
  that a script can evaluate.
- A machine-readable declaration of the tier in the PR, so the tier taken is part of the record.
- Session modes as emphasis-only overlays, with an explicit statement that a mode never changes a
  requirement.
- A fitness function that fails a PR whose diff exceeds the tier it declared.

## Out of scope

- Any change to the invariants. Tiers scale *process*, never invariants 1–25.
- Automatic tier selection. A human or agent declares the tier; the gate only checks the declaration
  against the diff. Inferring the tier from the diff would make the check circular.
- The ADR-0037 dispatcher and its parallel-worktree execution model. Still its own task.
- Modes as anything an agent's tools enforce — they are prompt-level emphasis and nothing more.

## Contracts touched

None. This is process governance; no `contracts/`, no `policies/`, no runtime code.

## Data owned

None.

## Design sketch

**Tiers.** Each tier states what it still requires. The entry condition is a property of the diff so
that a reviewer can check the declaration rather than debate it.

| Tier | May be taken when | Still required | Waived |
|---|---|---|---|
| `full` | always available; the default | everything in the definition of done | nothing |
| `quick` | no behaviour change a user or another repo can observe: docs, comments, chore, CI config, test-only refactor | invariant compliance, review, all gates that run | approved spec; tests-first ordering where no test exists to write |
| `bugfix` | a defect exists with a reproduction, and the fix is confined to one submodule | **a failing test first**, that test passing after, all gates, review | a separate approved spec — the failing test *is* the specification |

**The floor no tier crosses.** A change is security-relevant if its diff touches any of: authorization,
tenant scoping or RLS, audit emission, the agent↔control-plane wire, secret handling, `policies/`,
`contracts/`, or CI isolation. Security-relevant changes take `full` regardless of size. This is
deliberately over-broad — a false positive costs a spec nobody needed, a false negative costs an
invariant.

**Declaration.** The PR body carries one line, `Ceremony: full|quick|bugfix`. The PR template gains
the field. Absent the line, the tier is `full` — the safe default is the one you get by doing nothing.

**Enforcement.** `scripts/check-ceremony-tier.sh` reads the declared tier and the diff, and fails when
the diff exceeds what the tier permits. It follows the conventions the existing gates already use: a
missing prerequisite is a hard failure rather than a skip, and the message names the tier that would
have been valid.

**Modes** are documentation. `governance/docs/process/modes.md` describes each and what it makes an
agent look at first. No mode alters a requirement, no mode is declared in a PR, and no gate reads
them. If a mode ever needs to change what is required, it has become a tier and needs this spec
amended.

## Acceptance criteria (each becomes a test)

- [ ] **AC1:** A PR declaring `Ceremony: quick` whose diff changes a `.go`, `.ts`, or `.astro` file
      outside `*_test.go` / `*.test.ts` fails the gate, and the failure names `full` or `bugfix` as
      the valid tiers.
- [ ] **AC2:** A PR declaring `Ceremony: bugfix` whose diff spans two submodules fails the gate,
      citing invariant 23.
- [ ] **AC3:** A PR declaring `Ceremony: quick` or `bugfix` whose diff touches any security-relevant
      path fails the gate and names the path that forced `full`.
- [ ] **AC4:** A PR with no `Ceremony:` line is treated as `full` and the gate passes without the
      declaration — absence never grants a waiver.
- [ ] **AC5:** A PR declaring `Ceremony: bugfix` passes only if the diff adds or modifies at least one
      test file. A bugfix with no test is a failure, not a warning.
- [ ] **AC6:** The gate hard-fails, rather than skipping, when it cannot determine the diff — for
      example on a shallow clone with no merge base.
- [ ] **AC7:** `docs/process/modes.md` exists, is indexed, and states in its own text that a mode
      never changes a requirement. No script reads it.
- [ ] **AC8:** `docs/process/agdd.md` and `docs/process/definition-of-done.md` state where tiers
      apply, so the spec requirement and its exceptions are described in the same place rather than
      only here.

## Open questions

1. **Who may declare `quick`?** Anyone opening a PR, or only after a reviewer agrees? Self-declaration
   is faster and is what the gate assumes; requiring agreement makes the tier useless for the
   one-line fixes it exists for. Leaning self-declared and gate-checked.
2. **Should the tier live in the commit message rather than the PR body?** The commit is the durable
   record and the PR body is not; against that, the gate runs on a PR and squash-merge rewrites the
   message anyway.
3. **Is `quick` distinguishable from `bugfix` in practice**, or does one of them absorb the other? A
   docs typo and a one-line defect fix feel different but may not need different rules.
4. **Does the security-relevant path list belong here or in `invariants.md`?** Here it is a spec
   detail that changes with the tree; there it is a rule. It is currently a spec detail, which means
   changing it does not need an ADR — that may be too easy.
