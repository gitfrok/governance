# SPEC-0012: Ceremony tiers & session modes

- **Status:** Approved (implemented)
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

- [x] **AC1:** A PR declaring `Ceremony: quick` whose diff changes a `.go`, `.ts`, or `.astro` file
      outside `*_test.go` / `*.test.ts` fails the gate, and the failure names `full` or `bugfix` as
      the valid tiers.
- [x] **AC2:** A PR declaring `Ceremony: bugfix` whose diff spans two submodules fails the gate,
      citing invariant 23.
- [x] **AC3:** A PR declaring `Ceremony: quick` or `bugfix` whose diff touches any security-relevant
      path fails the gate and names the path that forced `full`.
- [x] **AC4:** A PR with no `Ceremony:` line is treated as `full` and the gate passes without the
      declaration — absence never grants a waiver.
- [x] **AC5:** A PR declaring `Ceremony: bugfix` passes only if the diff adds or modifies at least one
      test file. A bugfix with no test is a failure, not a warning.
- [x] **AC6:** The gate hard-fails, rather than skipping, when it cannot determine the diff — for
      example on a shallow clone with no merge base.
- [x] **AC7:** `docs/process/modes.md` exists, is indexed, and states in its own text that a mode
      never changes a requirement. No script reads it.
- [x] **AC8:** `docs/process/agdd.md` and `docs/process/definition-of-done.md` state where tiers
      apply, so the spec requirement and its exceptions are described in the same place rather than
      only here.

## Resolutions (answered by the implementation)

The four questions this spec opened are answered below. Implementation forced each one — none could
be deferred past writing the gate.

1. **Who may declare `quick`?** **Self-declared, gate-checked.** Requiring a reviewer to agree first
   would make the tier useless for the one-line fixes it exists for — the round trip costs more than
   the ceremony it saves. The mitigation is that the declaration is not trusted: the gate asserts the
   diff is entitled to the tier, so a wrong declaration is a red build rather than a quiet waiver.

2. **Commit message or PR body?** **PR body.** The gate runs on a pull request and that is where CI
   can read the declaration; squash-merge rewrites the message anyway, so the commit was never the
   durable record it looked like. The cost is real and worth naming: after the squash the tier is not
   in git history, only in the PR. If that becomes a problem the fix is to have the merge commit carry
   it, not to move the declaration.

3. **Are `quick` and `bugfix` distinct?** **Yes, and they waive for different reasons.** `quick`
   waives the spec because there is no behaviour to specify. `bugfix` waives the *separate* spec
   because the failing test is the specification — and therefore *requires* that test, which `quick`
   does not. Collapsing them would either force a test onto a docs typo or let a defect fix ship
   without one.

4. **Where does the security-path list live?** **In the gate, not in `invariants.md`.** The list
   tracks the tree's layout — `policies/`, `contracts/`, `.github/workflows/`, and path substrings
   like `authz`, `tenant`, `rls`, `audit` — and layout changes without any decision changing. Putting
   it in `invariants.md` would mean an ADR to add a directory. What belongs in governance prose is the
   *rule*, and that is now in `../process/definition-of-done.md` and `../process/agdd.md`: a
   security-relevant change takes `full`. The list is reviewed like any other code, and it is
   deliberately over-broad, so the failure mode of getting it wrong is a spec nobody needed.

## Implementation

`scripts/check-ceremony-tier.sh` — generated into all five repos from
`canonical/agent-surfaces/shared/` by the ADR-0037 pipeline, so there is one source and drift fails
`make surfaces-check`. Tested by `scripts/test-ceremony-tier.sh`, which builds a throwaway git repo
per case and asserts the exit code: 13 cases, one or more per acceptance criterion above.

`docs/process/modes.md` carries the modes (AC7). `agdd.md` and `definition-of-done.md` state where
tiers apply (AC8), so the spec requirement and its exceptions are described together rather than only
here.
