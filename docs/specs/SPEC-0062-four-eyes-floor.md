# SPEC-0062: The four-eyes floor

- **Status:** Implemented (2026-08-21) — T-0079; bundle rule + service exclusion proven.
  Approved (2026-08-21) under Accepted ADR-0085.
- **Owner:** platform
- **Context(s):** Policy (the bundle rule), Code Review (fact assembly). No contract change.
- **ADRs:** 0085 (decides this), 0006, 0029 §4
- **Task(s):** T-0079 (governance + backend)

## Problem / context

`required_approvals = 0` is legal and unprotected targets require nothing; the author's approval
counts toward the requirement. The merge gate's promise is review, and both facts are holes in it.

## In scope

- The floor as a second inequality in the bundle's `sufficient_approvals`.
- Author exclusion in the server-side assembly of `valid_approvals`.

## Out of scope

- Any wire or contract change. The facts already exist on the decision input.
- Tenant-level exceptions to the floor (ADR-0085 names the honest path if it bites).

## Acceptance criteria (each becomes a test)

- [x] **AC1** A merge with two non-author approvals is allowed even when `required_approvals`
      is `0` — the floor is the only thing demanding them, and it is enough.
- [x] **AC2** A merge with one valid approval is denied whatever `required_approvals` says
      (`0`, `1`, `2`) — nothing lowers the floor.
- [x] **AC3** The author's own approval never counts: an MR whose only approval is its author's
      presents `valid_approvals = 0`, and the author approving changes no gate outcome. The
      review itself is still recorded and audited.
- [x] **AC4** Two distinct non-author approvals satisfy the floor on an unprotected target;
      adding the protection rule's higher requirement still raises the bar (max wins, both
      inequalities must hold).
- [x] **AC5** The floor is asserted in the bundle's own tests, beside the existing approval-gate
      cases, so a refactor of `sufficient_approvals` cannot drop it silently.

## Governance mapping

| Objective | How |
|---|---|
| G4 review integrity | No merge lands on fewer than two people's judgment; never the author's alone among them. |

## Open questions / assumptions

1. Two-person tenants cannot merge until a third account exists. That is the floor working;
   ADR-0085 records the exception path if it proves real.
