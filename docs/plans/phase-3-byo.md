# Plan — Phase 3: BYO & commercial

**Status:** **Active (2026-08-14)**
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

- [ ] PR-20: a data plane installs into GKE, EKS and AKS from the chart plus an enrolment token, and
  self-registers over an outbound-only connection.
- [ ] PR-21: a signed release rolls out by reconcile and rolls back on failure, with no inbound access
  and no half-applied state left silent.
- [ ] PR-22: a tenant's declared cloud/region is enforced, contradiction is visible, and an evidence
  pack shows placement over its range with honest gaps.
- [ ] PR-23: usage is metered centrally, visible before an envelope is reached, enforced by
  throttling — with git available in every state and every deferred dimension labelled as deferred.
- [ ] The whole path proven once end to end on a real customer-shaped cluster, not a harness.

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
