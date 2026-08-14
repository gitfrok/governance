# T-0034: Fair-use metering, envelopes, and the usage view

- **Status:** Todo
- **Phase / Epic:** 3 / EP-18 (commercial)
- **Repo(s):** governance (additive telemetry/envelope messages), backend, bff, webfrontend — ADR-0027
  order, one commit per repo
- **Spec:** docs/specs/SPEC-0041-fair-use-metering.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0061, 0008, 0018, 0011, 0017
- **Owner:** unassigned

## Goal
Meter usage centrally, show it before an envelope is reached, and enforce by throttling — with git
untouched in every state.

## Acceptance criteria (test-first)
SPEC-0041 AC1–AC10. The two that must not be softened:
- [ ] AC7: git push, fetch, clone and reads succeed under a breach of **every** dimension — one test
      per dimension, because this is the promise a well-meaning throttle breaks first.
- [ ] AC8: no repository is ever made read-only for a commercial reason; the durability read-only
      mode (ADR-0018) stays distinguishable in the product.
- [ ] AC2: every deferred dimension reads as "not metered", never as zero or within-envelope.

## Tests to write first
- unit: counter derivation from telemetry; restart without double-count or lost interval; gap
  rendering for a silent data plane.
- integration: threshold notice before breach; CI concurrency reduction with queued jobs delayed and
  visibly caused, never dropped.
- product: the git-availability matrix (AC7) and the read-only distinction (AC8).

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony.

## Notes / open questions
Repository storage and index size are sizes, not events, and are the likeliest AC2 deferrals — decide
that before building the view, so it never implies coverage it lacks. Prices and tiers stay out
(ADR-0008 follow-up); nothing here bills.
