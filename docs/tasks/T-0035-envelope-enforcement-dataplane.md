# T-0035: Apply the envelope throttle in the data plane

- **Status:** Done
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
- **Both** — the gauge for shape, the claim gate for the hard bound. ← **CHOSEN** — recorded in the
  exit record below before the code was written: `MaxCIConcurrency` binds the claim gate (the hard
  bound on in-flight dispatch), `QueueDepthCap` shapes the scaler gauge input.

## Acceptance criteria (test-first)

- [x] AC1: `platform/agentclient` applies `EnvelopeStateUpdate` — currently ignored by comment — and
      sends `EnvelopeStateAck` from the real client, not only from a test's stub.
- [x] AC2: a breached CI envelope reduces in-flight dispatch to the published cap, per tenant.
- [x] AC3: queued jobs are **delayed, never dropped**, and the delay is visible as a cause on the
      job (SPEC-0041 AC5).
- [x] AC4: running jobs finish; the cap never cancels work already dispatched.
- [x] AC5: git push, fetch, clone and reads stay fully available while the cap is in force — the
      per-dimension assertion SPEC-0041 AC7 already makes structurally, now made behaviourally on a
      throttled plane.
- [x] AC6: envelope state survives an agent reconnect: a data plane that reconnects re-applies the
      current generation rather than running unthrottled until the next evaluation.
- [x] AC7: a data plane that has never received envelope state runs unthrottled — absence is not a
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

## Exit record (2026-08-16)

Closed in one backend landing: backend **a9ed620**, pin-bumped by super-repo **9f526d0** as its own
commit immediately after. No governance contract change was needed — `EnvelopeStateUpdate`,
`EnvelopeStateAck` and the metering seams already carried everything this task consumes (T-0034's
contract, proven on the wire in SPEC-0041 AC9). All proofs ran through the full backend gate
sequence: `gofmt` clean, `go vet`, `go build`, `go test ./internal/arch/... -v`, and
`go test -race -count=1 ./...` against the real-Postgres harness at `127.0.0.1:15432` with **zero
failures and zero durability skips**.

**The decision, recorded before the code:** **Both**. `MaxCIConcurrency` binds the dispatcher's
claim gate — the hard, immediate bound on in-flight dispatch — and `QueueDepthCap` caps the
queue-depth gauge KEDA reads, so the replica count shapes itself toward the envelope. One number
for the bound, one for the shape, both sourced from the SAME `EnvelopeStateUpdate`.

**Apply semantics (the consequence SPEC-0046 AC3 renders):** the data plane treats each update as
ABSOLUTE desired state, not a delta. The metering service's evaluation publishes the throttled
caps on a breach and 0/0 on a clean one — so **0 means unthrottled/lift**, and the throttle CAN
lift. The wire comment on `EnvelopeStateUpdate`'s cap fields says "0 = unchanged"; the control
plane's actual behavior contradicts it. The implementation follows the BEHAVIOR (the control plane
is the sole metering authority, ADR-0061); the stale comment is carried as an honest observation
for a future contract-hygiene pass, not patched here (governance changes are not owned by this
task's repo scope).

**Per-replica honesty (the note this task owned):** the claim gate binds PER REPLICA — each data
plane process holds its own `Caps` and caps its own in-flight count; replicas do not share the
count. "Reduces in-flight dispatch to the published cap" is true per data plane, not across a
tenant's replicas as a sum. The gauge half is what shapes the replica count itself.

**AC1 — real client applies and acks:** `TestEnvelopeStateUpdateAppliesAndAcks`
(platform/agentclient) runs the WHOLE path over the real client and a real gRPC gateway: a
published generation is applied into the sink and answered with an `EnvelopeStateAck` the control
plane records as applied; a newer generation is applied again on the live stream. This test also
repaired a latent date-drift fault in the package's rig: the fixed 2026-08-15 fake clock had
fallen behind the wall clock, reading the wall-dated DevCA root as not-yet-valid and refusing
every CERTIFIED admission — the old install proofs passed only via the enrolment stream. The
clocks are now wall-anchored (gateway_integration_test's documented discipline), so admission is
genuinely exercised again.

**AC2 — in-flight reduced to the cap:** `TestClaimGateBelowCapDispatchesFreely`,
`TestClaimGateAtCapDelaysNotDrops`, `TestCapsUpdateIsObservedByClaimGate` (dispatcher, `-race`).

**AC3 — delayed, never dropped, cause visible:** `TestClaimGateAtCapDelaysNotDrops` (the queue
keeps the jobs) + `TestDelayedJobCarriesEnvelopeThrottleCause` (`api.DelayCauseEnvelopeThrottle`
on the job view).

**AC4 — running work never cancelled:** `TestCapNeverCancelsRunningWork` — a cap landing while
jobs are in flight lets them finish; cancellation counts stay zero.

**AC5 — git stays fully available:** structurally, the throttle path only stores caps and gates
CI dispatch — it references no git surface, and the architecture fitness holds; behaviourally, the
entire git-serving suite passes with the throttle wired and caps live, and the agentclient path
proves the update handler can never block or fail the stream into a git-affecting state (a sink
error becomes an honest not-applied ack, never a stream end). Live git traffic on a throttled
plane is the E2E/cluster lane's proof (board #22 / T-0042), carried honestly.

**AC6 — reconnect re-applies:** the same integration test cancels the certified stream and
reconnects: the current generation is re-applied before any new evaluation (the gateway resets
its delivered-generation per stream, so the reconnect re-delivers).

**AC7 — absence is not a cap of zero:** `TestFreshCapsRunUnthrottled` — a dispatcher whose caps
were never touched dispatches freely; `Config.Envelope == nil` applies every update trivially
(nothing to throttle), and no code path converts "never received" into a 0-cap.

## Exit-record amendment (2026-08-16, Phase 3.1 final review)

The Phase 3.1 correctness review observed that the wire proof above applied the caps into a
RECORDING STUB (`recordingEnvelopeSink`), so the data plane's actual CONSUMPTION of the caps was
proven only compositionally. Backend **7c05a86** closes that gap with a real-wire consumption test:
`TestEnvelopeStateCapsBindTheRealDispatcher` (platform/agentclient) wires the agent's Envelope sink
to the SAME `ci.EnvelopeCaps` holder the real CI dispatcher reads through `EnvelopeThrottle` on
every tick (`ci.NewRuntime`'s `WithEnvelopeThrottle(caps)`). Over the real mTLS channel: a breach
generation (1, 2) lands in the holder and five queued jobs render as the CAPPED depth 2 on the
KEDA gauge endpoint; the recovery generation (0, 0) LIFTS the caps and a fresh burst renders its
FULL depth; both generations are recorded by the control-plane delivery as applied acks. The
claim-gate half (`MaxCIConcurrency`) binds off the same holder — proven against a held in-flight
count by the dispatcher suite named under AC2. Same full gate sequence, zero failures, zero
durability skips.
