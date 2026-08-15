# T-0043: Usage-view divergence health gates and envelope-state telemetry through bff → webfrontend

- **Status:** Todo — **blocked-by T-0035** (the envelope throttle must be applied in the data plane
  before its application is observable; SPEC-0046 AC3's explicit dependency)
- **Phase / Epic:** 3.1 / EP-23 (usage-view truth and the PR-7 distinction)
- **Repo(s):** backend, bff, webfrontend — ADR-0027 order, one commit per repo
- **Spec:** docs/specs/SPEC-0046-usage-view-pr7-distinction.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0061, 0018, 0008
- **Owner:** unassigned

## Goal

Make PR-23's view tell the truth end to end: divergence between control-plane-derived telemetry and a
data plane's own report surfaces as a health finding with both numbers shown, near-envelope and
exceeded states are visible per dimension before enforcement acts, and the **applied** throttle —
not merely the delivered one — is observable from backend through bff to the customer's browser.

## Acceptance criteria (test-first)

SPEC-0046 AC1, AC2, AC3, AC5 (AC4 is T-0044's):
- [ ] AC1: a divergence between control-plane telemetry and a data plane's own report surfaces as a
      health finding in the usage view, with both numbers shown — it never adjusts a metered number;
      the finding is the product, not an input (SPEC-0041 AC1's rule, rendered where the customer
      looks).
- [ ] AC2: near-envelope and exceeded states are visible to the customer per dimension, before
      enforcement acts — the state names its dimension, its trend and which envelope behaviour
      follows (SPEC-0041 AC4's notification is not the customer's first sight of trouble).
- [ ] AC3: throttle application is observable end-to-end — telemetry reflects the applied throttle in
      the customer's cluster. **Untestable and not claimable until T-0035 lands.**
- [ ] AC5: unmetered dimensions render "not metered", never zero, and git is never blocked in any
      envelope state — regression pins wired to fail the build if either regresses (SPEC-0041 AC2/AC7).

## Tests to write first

Per SPEC-0046 § Test plan:
- backend: divergence-finding derivation with both numbers preserved (AC1); per-dimension
  near/exceeded state computation ahead of enforcement (AC2); applied-throttle reflection once T-0035
  lands (AC3).
- bff: nil-gap propagation — a gap or "not metered" marker must survive aggregation and never
  collapse to zero on its way to the browser (AC5).
- webfrontend vitest: per-dimension envelope states and "not metered" rendering (AC2, AC5).
- regression pins: never-zero for unmetered dimensions, never-blocked git per dimension (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- bff: `gofmt` / `go build` / `go vet`, boundary/arch fitness, `go test` — aggregation only, no
  business logic.
- webfrontend: vitest suite plus build/typecheck.

## Notes / open questions

Where a cause or state field the ACs need is missing from an existing view contract, the additive
change goes first under its own governance PR (SPEC-0046 Contracts touched). The view renders from
the same counters envelope decisions were made from (SPEC-0041 AC10) — no second internal number.
If T-0035's chosen mechanism does not report enough applied-state fact for AC3, that gap is T-0035's
exit record to carry, not a reason to weaken the AC (SPEC-0046's assumption).
