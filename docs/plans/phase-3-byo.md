# Plan — Phase 3: BYO & commercial

**Status:** **Implementation complete (2026-08-15)** — every task is proven by named tests at its exit
pin; the phase's real-cluster exit criterion is carried to T-0003's cluster lane (verdict below)
**Objective:** a customer runs the data plane in their own GKE/EKS/AKS under a flat plan — installed
from a chart, self-registered over an outbound-only connection, upgraded by reconcile, pinned to a
declared region, and metered against fair-use envelopes that never block git
(PRD §5 Phase 3, §6; roadmap §Phase 3).

Scope is exactly **PR-20…PR-23**. Phase-2 carry-overs stay carry-overs: T-0029 (the CI scan-report
ingest) and the two recorded posture limits are tracked in `../backlog/README.md`, not folded in here.

## What was already decided

Phase 3 is unusual in that its architecture predates its plan. **ADR-0009** splits control and data
plane, **ADR-0010** fixes GKE/EKS/AKS as the portability target, **ADR-0011** makes the connection
outbound-only, **ADR-0013** packages it as Helm plus an Operator, and **ADR-0017** fixes the agent
protocol — with `contracts/proto/agent/v1` already published and unimplemented.

Two decisions were open and blocked honest specs. Both are now settled:

- **ADR-0060** — a one-time enrolment token bootstraps, and the control plane issues and rotates
  short-lived certificates over the channel the agent already holds. SPIFFE/SPIRE was rejected as a
  second distributed system per install across three clouds; per-cloud workload identity was rejected
  for putting provider claims inside the trust model ADR-0010 exists to keep out. This closes
  ADR-0017's cert-issuance follow-up; **proxy-only egress remains open** and is the one thing that can
  block a customer install outright.
- **ADR-0061** — the control plane counts, from telemetry it already receives. A customer's own
  cluster is not the source of truth for the number they are measured against.

## Workstreams

| Epic | Requirement | Tasks | Specs |
|---|---|---|---|
| **EP-15** BYO data plane | PR-20 | T-0030 | SPEC-0038 |
| **EP-16** Packaging & lifecycle | PR-20, PR-21 | T-0031, T-0032 | SPEC-0039 |
| **EP-17** Residency & evidence | PR-22 | T-0033 | SPEC-0040 |
| **EP-18** Commercial | PR-23 | T-0034 | SPEC-0041 |

All four specs were Approved (2026-08-14); all five tasks are now **Done** with exit records in
`../tasks/` (see the exit verdict below).

## Sequence and critical path

**EP-15 gates the phase.** Nothing can be shipped to, upgraded on, or metered from a data plane that
cannot connect, so T-0030 comes first and alone. T-0031 follows it (an install is only real if it
self-registers), then T-0032 on top of the install.

T-0033 and T-0034 are independent of each other and both need only the agent channel, so they run in
parallel behind EP-15 — but T-0033's pack section needs the placement facts the registry gets in
T-0030, and T-0034's counters need telemetry the same channel carries.

The honest ordering is therefore: **T-0030 → T-0031 → T-0032**, with **T-0033** and **T-0034**
starting as soon as T-0030 lands.

## What this phase must not do

- **Never block git.** Every envelope state leaves push, fetch, clone and reads fully available
  (SPEC-0041 AC7). Read-only stays reserved for the PR-7 durability mode (ADR-0018).
- **Never open an inbound path** into a customer's cluster, for upgrades, debugging or anything else
  (SPEC-0039 AC4, asserted by test).
- **Never let a customer attest their own compliance** into a control section of an evidence pack
  (SPEC-0040 AC7, the ADR-0029 §4 rule).
- **Never show usage coverage we do not have.** A dimension we cannot derive centrally reads as "not
  metered", never as zero (SPEC-0041 AC2).
- **No air-gapped install** (PRD non-goal 1) and **no metered overage billing** (ADR-0008).

## Exit criteria

- [x] PR-20: a data plane installs into GKE, EKS and AKS from the chart plus an enrolment token, and
      self-registers over an outbound-only connection.
- [x] PR-21: a signed release rolls out by reconcile and rolls back on failure, with no inbound access
      and no half-applied state left silent.
- [x] PR-22: a tenant's declared cloud/region is enforced, contradiction is visible, and an evidence
      pack shows placement over its range with honest gaps.
- [x] PR-23: usage is metered centrally, visible before an envelope is reached, enforced by
      throttling — with git available in every state and every deferred dimension labelled as deferred.
- [ ] The whole path proven once end to end on a real customer-shaped cluster, not a harness.
      *(carried to T-0003's cluster lane — see exit verdict)*

### Exit verdict (2026-08-15)

**Implementation complete, demonstration carried.** PR-20…PR-23 are met at the code level: every
task-level acceptance criterion is proven by named tests at the exit pins — T-0030 (SPEC-0038 AC1–AC9:
contracts governance@5e33e90 + authz governance@2c268d3, backend@8e5d013), T-0031 (SPEC-0039 AC1/AC2:
backend@4b26cb2, super-repo@150cc2b), T-0032 (SPEC-0039 AC3–AC7: governance@dea5476, backend@85b773c,
super-repo@149b3e2), T-0033 (SPEC-0040 AC1–AC8: governance@0e61302, backend@c630a1e), T-0034
(SPEC-0041 AC1–AC10: governance@5dff9b3, backend@d3f4ad6, bff@e2344de, webfrontend@95f77be+0e80261).
All pins are commits on each repo's `main`, merged by fast-forward, no force-push.

**The fifth criterion is carried, not met.** The whole path proven once end to end on a real
customer-shaped cluster is infrastructure-bound exactly the way Phase 1's gVisor/durability steps and
Phase 2's measured-freshness steps were: recorded as carried proof against T-0003's cluster lane,
never counted as met. The conformance matrix (`deploy/conformance/byo-dataplane.md`, 14 rows) exists
and states per row what was verified where — every row is harness-evidence only, every real-cluster
column reads "not run". Carried with it: SPEC-0039 AC8's forward/backward migration proof on real
state (named in T-0031's AC list, not among its exit evidence — recorded as carried, not papered
over), the in-memory agent/residency stores (Postgres adapters), the enrolment CA's production key
custody (ADR-0057-scoped platform-secrets follow-up), the residency Declare wire surface, the PR-7
read-only product distinction, and the clock-skew runbook entry. Full carried set in
`../backlog/README.md`.

**Carried out of the phase by the code review (2026-08-15).** The review found the envelope
throttle computed and delivered but never applied: no data-plane consumer reads it, so SPEC-0041
AC5's behaviour does not happen in a customer's cluster. T-0034's record now says so, and **T-0035**
owns the data-plane half plus the design decision it needs — the CI dispatcher claims one job per
tick and scales by KEDA replicas, so a per-tenant cap has nowhere to bind yet. Two smaller findings
were fixed in place: the agent CA classified a certificate's validity window before establishing
trust (backend@e722046), and the no-inbound fitness scan's tree list is now derived from the
composition root rather than maintained by hand, after phase 3 added two control-plane modules it
did not cover.

**The phase's "must not" list held.** Git is never blocked in any envelope state (one test per
dimension, SPEC-0041 AC7); no inbound path exists into a customer's cluster (asserted by the
architecture fitness test, SPEC-0039 AC4, and the chart renders zero inbound surfaces); no customer
self-attestation can reach a control section (SPEC-0040 AC7, excluded by construction); deferred
metering dimensions render as "not metered", never zero (SPEC-0041 AC2).

## Risks

- **Proxy-only egress (open).** ADR-0017's remaining follow-up. A customer whose egress permits only
  an HTTP proxy cannot install at all, and we will discover this during a sale rather than in a test.
- **Three clouds, one team.** SPEC-0039 AC1 forces the conformance matrix to say what was verified on
  a real cluster versus a harness, because the alternative is a matrix that reads green and means
  little.
- **Metering coverage.** Storage and index size are sizes, not events; if several dimensions defer,
  "fair use" is enforced on a subset and the usage view must say so plainly.
- **We operate what we cannot reach.** Every failure mode in a customer's cluster is diagnosed from
  telemetry alone. Staleness rendered as health is the specific way that goes wrong, which is why
  SPEC-0038 AC8 and SPEC-0039 AC6 both name it.
- **Clock skew.** Short-lived certificates plus a skewed customer cluster disconnect healthy data
  planes and present as network faults.
