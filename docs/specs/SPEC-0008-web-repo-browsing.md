# SPEC-0008: Web repo browsing UX (browser + diff + palette)

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s)
- **Owner:** platform
- **Context(s):** webfrontend
- **ADRs:** 0015, 0023
- **Task(s):** T-0015

> **Deployment premise amended 2026-09-22 — no request or response shape changes.** ADR-0094
> decision 3 moved the repository surface data-plane-side, so the routes this spec defines are served
> by a `bff`+`webfrontend` pair on the **data plane**, not the control plane as ADR-0093's partition
> had it. Every criterion below stands unaltered; what changed is which deployment serves them.
> **SPEC-0070** carries the partition contract and the two boot refusals that enforce it.

## Problem / context
Ship the GitHub-clean repo browsing experience consuming only the BFF.

## In scope
- SSR repo browser: tree, file view, diff view; a command palette for navigation.

## Out of scope
- Editing/review UI (later phase).

## Contracts touched
Consumes the BFF view API (generated TS types from `governance/contracts`).

## Data owned
No data owned; presentation only.

## Acceptance criteria (each becomes a test)
- [ ] AC1: Browse tree, view a file, and view a diff, served via SSR from the **BFF only**.
- [ ] AC2: A command palette provides quick navigation (ADR-0015).
- [ ] AC3: The app never calls `backend` directly (invariant 22) — enforced by test/lint.

## Governance mapping (G1–G9)
| Objective | How |
|---|---|
| G2 least privilege | UI relies on BFF/PDP decisions |
| (UX) | ADR-0015 clean surface |

## Non-functional
First-contentful-paint within budget; accessible (keyboard/pallette).

## Open questions / assumptions
- Exact palette command set to refine with design.
