# T-0035: Apply the envelope throttle in the data plane

- **Status:** Todo
- **Phase / Epic:** 3 / EP-18 (commercial)
- **Repo(s):** backend (agent client, CI dispatch), governance only if the desired-state message
  needs a field it does not already carry
- **Spec:** docs/specs/SPEC-0041-fair-use-metering.md (Approved) — AC5 and AC9's second half
- **ADRs:** 0061, 0008, 0011, 0017, 0018
- **Owner:** unassigned

## Goal

Make the fair-use throttle real where the work happens. Today the control plane derives counters,
evaluates envelopes, publishes desired state and handles the ack; the customer's cluster does
nothing with it, so a breached CI envelope reduces nothing (phase-3 review H2).

## The decision this task owns

The dispatcher claims **at most one job per tick** and scales by KEDA replicas
(`modules/ci/internal/dispatcher`), so `MaxCIConcurrency` has nowhere to bind yet. Pick one and
record it before writing code:

- **Claim gate** — the dispatcher refuses to claim beyond the tenant's cap. Simple and local; the
  cap binds per replica unless replicas share the count.
- **Scaler input** — the envelope caps the queue-depth gauge KEDA reads, so replicas scale down.
  Cluster-native, but coarse and slow to react.
- **Both** — the gauge for shape, the claim gate for the hard bound.

## Acceptance criteria (test-first)

- [ ] AC1: `platform/agentclient` applies `EnvelopeStateUpdate` — currently ignored by comment — and
      sends `EnvelopeStateAck` from the real client, not only from a test's stub.
- [ ] AC2: a breached CI envelope reduces in-flight dispatch to the published cap, per tenant.
- [ ] AC3: queued jobs are **delayed, never dropped**, and the delay is visible as a cause on the
      job (SPEC-0041 AC5).
- [ ] AC4: running jobs finish; the cap never cancels work already dispatched.
- [ ] AC5: git push, fetch, clone and reads stay fully available while the cap is in force — the
      per-dimension assertion SPEC-0041 AC7 already makes structurally, now made behaviourally on a
      throttled plane.
- [ ] AC6: envelope state survives an agent reconnect: a data plane that reconnects re-applies the
      current generation rather than running unthrottled until the next evaluation.
- [ ] AC7: a data plane that has never received envelope state runs unthrottled — absence is not a
      cap of zero.

## Tests to write first

- unit: the claim gate at, below and above the cap; queued-not-dropped; running-not-cancelled.
- integration: control plane publishes → real agent client applies → dispatch observes the cap →
  ack returns; then reconnect and re-apply.
- product: git availability while throttled (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — it changes dispatch semantics.

## Notes / open questions

Whether the cap is per data plane or per tenant across replicas decides whether the count must be
shared state. Per-replica is the cheap read of "reduce concurrency" and is honest only if the
record says so.
