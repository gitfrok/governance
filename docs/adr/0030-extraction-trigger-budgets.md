# ADR-0030: Extraction-trigger budgets for the modular monolith

- **Status:** Accepted
- **Date:** 2026-08-03
- **Deciders:** platform
- **Governs:** G8 cost governance
- **Relates to:** ADR-0026 (service-based target — the triggers), ADR-0025 (modular monolith),
  ADR-0022 (HCLC) · **Tasks:** T-0009 (fitness functions)

## Context

ADR-0026 makes extraction **trigger-driven, never scheduled**, and lists four triggers. Trigger 4
is *"the monolith binary's build/test/deploy time crosses an agreed budget"* — but no budget was
ever agreed, so trigger 4 cannot fire. The other three (scaling profile, blast radius, ownership)
are judgement calls that a person raises; trigger 4 is the one meant to be noticed by a machine,
and today nothing notices it.

T-0009 builds the report that measures the observable signals. It needs numbers to compare against,
and picking them is a decision, not an implementation detail (invariant 12) — so the mechanism
landed with provisional values in the backend's `internal/arch` (`DefaultBudgets`), pointing here.
This ADR settles them; those values are now the agreed budget ADR-0026 refers to, not a placeholder.

Two things make the numbers hard to set well right now:

1. **The tree is nearly empty.** Two modules, a build under a second. Any budget we set is
   extrapolation, and one set too tight will fire on ordinary Phase-1 growth and train people to
   raise it without thinking — which is worse than having no budget at all.
2. **Under BYO, extraction is not free.** Each extracted service adds a pod to the customer's
   cluster (ADR-0026, G8). A budget that fires eagerly pushes cost onto customers to save our CI
   minutes, which is the wrong trade.

So these are deliberately loose. A budget's job here is to catch the step change — the commit that
doubles the build — not to police steady growth.

## Decision

We will adopt the following budgets, evaluated by the T-0009 report on every backend CI run. A
crossing **fails the build**, and the fix is either to make it faster or to open the extraction
conversation ADR-0026 describes. It is never to silently raise the number: a change here is a PR
against this ADR, which is the point of writing them down.

| Signal | Budget | Why this number |
|---|---|---|
| Monolith build (`go build` over product packages) | **120 s** | Roughly the point where the edit–build loop stops feeling interactive; also ADR-0026 trigger 4 proper. |
| Monolith test (`go test` over product packages) | **300 s** | Five minutes is about the limit of a PR check people will wait for rather than context-switch away from. |
| Per-module fan-out (modules one module depends on) | **5** | Not an ADR-0026 trigger — an ADR-0022 cohesion signal. A module needing more than five siblings usually has the boundary in the wrong place, and extracting it as-is would just distribute the problem. |

Fan-in, per-module build time and package counts are **reported but not budgeted**. High fan-in
makes extraction expensive rather than overdue, so it belongs in the argument, not in a gate.

Two constraints on how the budgets are used:

- **Reported every run, not only on breach.** The decision ADR-0026 wants is informed by the
  trend, and a number recorded only once it is already a problem has no trend.
- **A breach opens a conversation, not a refactor.** Crossing a budget is evidence for trigger 4;
  the BYO cost gate (G8) still applies, and the answer may legitimately be "make it faster".

## Consequences

**Positive:** trigger 4 becomes observable, so extraction can be argued from measurements rather
than from an impression that the build got slow. The budgets are visible and versioned, so raising
one is a reviewed decision.

**Negative / costs:** the numbers are extrapolated from a two-module tree and will need revisiting
— most likely once Phase-1 lands the git plane and the real shape of the binary is known. Wall-clock
timings vary with the CI runner, so a breach near the boundary may be noise; the budgets are set
loose enough that this should mean a re-run, not a policy change.

**Follow-ups:**
- Revisit all three numbers at Phase-1 exit, when the monolith holds the git plane, identity, and
  CI control (T-0010–T-0017).
- Deploy time is named in ADR-0026 trigger 4 and is **not** budgeted here: nothing deploys yet.
  Add it when there is a pipeline to measure.
- Consider replacing wall-clock build time with a runner-independent measure (package count,
  compiled units) if CI variance turns out to be the dominant term.

## Alternatives considered

- **Leave trigger 4 unquantified** — rejected: it is the trigger specifically meant to be caught
  mechanically, and an unquantified trigger never fires. The other three already work by judgement.
- **Set tight budgets now and relax them as needed** — rejected: a gate that fires on ordinary
  growth teaches people to raise the number reflexively, and then it is decoration.
- **Report without gating** — rejected, and it is what T-0009 effectively did while this sat
  Proposed. A report nobody is required to read is how the build got slow in the first place;
  gating is what forces the conversation to happen once.
- **Budget per-module build time instead of the monolith's** — rejected: ADR-0026 trigger 4 is
  about the binary, and a per-module budget would push toward extracting whichever module is
  merely largest rather than whichever one has a reason to leave.
