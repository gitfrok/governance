# SPEC-0046: Usage view truth and the PR-7 read-only distinction

- **Status:** Approved (2026-08-15)
- **Owner:** platform
- **Context(s):** Control plane (meters, derives the view) · BFF (aggregates for the browser) · Web frontend (renders) · Data plane (applies the throttle) — ADR-0022
- **ADRs:** 0061 (metering authority — not revisited), 0018 (dual-loss fail-safe, the PR-7 read-only mode), 0008 (flat-rate + fair use)
- **Task(s):** — (Phase 3.1, epic EP-23; task to be filed; AC3 depends on T-0035 landing first)

## Problem / context

PR-23's usage view landed in Phase 3 (T-0034), and the phase review then found two honesty gaps the
view must close. First, the envelope throttle was computed and delivered but never applied in the
customer's cluster — **T-0035** owns the data-plane half, which makes this spec's end-to-end
observability explicitly dependent on it. Second, the carried "PR-7 read-only product distinction":
read-only is reserved for PR-7's durability failure mode (ADR-0018), and a commercial envelope state
must never render as read-only — the in-product distinction was owed when the usage view shipped and
is enforced here.

This spec fixes what the customer reads: divergence surfaced, not smoothed; envelope states visible
per dimension before enforcement; the *applied* throttle observable, not merely the delivered one;
every read-only state named by its cause; and the never-zero/never-blocked regression pins held for
Phase 3.1 epic **EP-23** (PR-23/PR-7). ADR-0061's authority is untouched: the control plane counts,
and nothing here adjusts a metered number.

## In scope

- Divergence between control-plane telemetry and data-plane reports as a rendered health finding.
- Near-envelope and exceeded states, per dimension, visible before enforcement.
- End-to-end throttle observability (delivered → applied → reflected in telemetry).
- Read-only state cause-identification across UI and API surfaces.
- Regression pins: "not metered" never renders as zero; git never blocked.

## Out of scope

- Overage billing (ADR-0008 forbids it without a superseding ADR) — a Phase 3.1 non-goal.
- Prices, tiers and plan names (ADR-0008's unit-economics follow-up).
- Any change to metering authority or counter derivation (ADR-0061 is not revisited).
- The PR-7 durability read-only mode itself — SPEC-0005/ADR-0018 own its behaviour; this spec only
  distinguishes it in the product.
- New enforcement behaviours beyond what PRD §6 and SPEC-0041 already fix.

## Contracts touched

None by default — the usage view surface landed with T-0034. Where a cause or state field the ACs
need is missing from an existing view contract, it is an additive change under its own governance PR
first.

## Data owned

The control plane owns the counters, the envelope states and the usage view; the BFF aggregates
without interpreting; the web frontend renders without deriving. The data plane owns its operational
counters and the applied-throttle facts it reports — inputs, never the number (ADR-0061 §2).

## Acceptance criteria (each becomes a test)

- [ ] AC1: A divergence between control-plane-derived telemetry and a data plane's own report
  surfaces as a health finding in the usage view, with both numbers shown. It never adjusts a metered
  number — the finding is the product, not an input (SPEC-0041 AC1's rule, rendered where the
  customer looks).
- [ ] AC2: Near-envelope and exceeded states are visible to the customer per dimension, before
  enforcement acts — the state names its dimension, its trend and which envelope behaviour follows,
  so the notification (SPEC-0041 AC4) is not the customer's first sight of trouble.
- [ ] AC3: Throttle application is observable end-to-end: telemetry reflects the **applied** throttle
  in the customer's cluster, not merely the envelope delivered as desired state. **Explicit
  dependency: T-0035 lands first** — until the data plane applies `EnvelopeStateUpdate`, this AC is
  untestable and must not be claimed.
- [ ] AC4: Any read-only state in the UI or API identifies its cause: the PR-7 durability mode
  (ADR-0018 — dual loss, audited override) or an envelope throttle effect. Commercial states never
  render as read-only (SPEC-0041 AC8's prohibition, now with the distinction the phase carried).
- [ ] AC5: Unmetered dimensions render "not metered", never zero — regression-pinned (SPEC-0041 AC2);
  and git is never blocked in any envelope state, asserted per dimension as before (SPEC-0041 AC7's
  per-dimension tests remain in force).

## Test plan

- Backend unit + integration tests: divergence-finding derivation with both numbers preserved (AC1);
  per-dimension near/exceeded state computation ahead of enforcement (AC2); applied-throttle
  reflection once T-0035 lands (AC3); cause-carried read-only state (AC4).
- BFF aggregation tests: nil-gap propagation — a gap or "not metered" marker must survive aggregation
  and never collapse to zero on its way to the browser (AC5).
- Web frontend vitest: state-cause rendering for every read-only surface (durability vs throttle vs
  never), per-dimension envelope states, and "not metered" rendering (AC2, AC4, AC5).
- Regression pins: never-zero for unmetered dimensions and never-blocked git per dimension, wired to
  fail the build if either regresses (AC5).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G8 Cost governance | fair use stays visible and honest per dimension — divergence shown, never smoothed into the number (AC1, AC2) |
| G5 Auditability | read-only states name their cause, so the audited durability mode and the commercial state cannot be confused (AC4) |
| G9 Least-privilege footprint | the view states what enforcement will do before it does it; no surprise degradation (AC2) |
| G1 Tenant isolation | findings, states and causes are tenant-scoped through the same view boundary as the counters |

## Non-functional

- The usage view renders from the same counters envelope decisions were made from (SPEC-0041 AC10);
  no second internal number is introduced for these states.
- Cause labels are contract vocabulary, not UI copy — the API identifies the cause so every consumer
  renders the same distinction.

## Open questions / assumptions

- Assumed: T-0035's chosen throttle mechanism (claim gate, scaler input, or both) reports enough
  applied-state fact for AC3; if it does not, the gap is T-0035's exit record to carry, not a reason
  to weaken this AC.
- Assumed: the PR-7 durability mode surfaces through a state the control plane already renders;
  if PR-7's mode has no product state yet, AC4's durability branch tests the API cause contract and
  the UI branch lands with PR-7's own work.
