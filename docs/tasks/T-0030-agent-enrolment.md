# T-0030: Agent enrolment, self-registration, and certificate rotation

- **Status:** Done (2026-08-15) — contracts governance@5e33e90 + authz governance@2c268d3,
  backend@8e5d013; AC1–AC9 each proven by named tests; recorded limits below
- **Phase / Epic:** 3 / EP-15 (BYO data plane)
- **Repo(s):** governance (additive `agent/v1` messages first, ADR-0027 order), then backend
- **Spec:** docs/specs/SPEC-0038-agent-enrolment-registration.md (Approved 2026-08-14 — RED may begin)
- **ADRs:** 0060, 0011, 0017, 0009, 0010
- **Owner:** unassigned

## Goal
Implement `AgentGateway.Connect`'s enrolment half: a one-time token brings a data plane up, the
control plane issues and rotates its certificate on the channel, and an operator can see and revoke
it. Nothing else in Phase 3 can be delivered to a data plane that cannot connect.

## Acceptance criteria (test-first)
SPEC-0038 AC1–AC9. The ones most likely to be faked, called out:
- [x] AC2: no token in any log, error, metric label, or file the install writes back — asserted by
      test, not by review.
- [x] AC3: identity comes from the certificate; a payload claiming another tenant is ignored *and*
      audited.
- [x] AC6: no degraded mode that accepts an unidentified data plane.
- [x] AC8: stale is distinguishable from healthy, and never rendered as healthy.

## Tests to write first
- unit: token single-use including the spent-then-failed path; rotation timing; refusal on expiry.
- contract: additive `agent/v1` messages pass `buf breaking` against the published contract.
- integration: full first `Connect` against a real gRPC server; rotation across a certificate
  boundary; revocation refusing the next connection.
- policy-isolation: a tenant-A certificate reaching nothing of tenant B's, coarse refusals.

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony — authorization, tenancy, audit, contracts.

## Notes / open questions
Proxy-only egress is unsolved (ADR-0017's remaining follow-up); a customer behind an HTTP-proxy-only
egress cannot install until it is. Clock skew disconnects healthy data planes and reads as a network
fault — put the symptom in the runbook with the code, not after the first incident.

## Exit record (2026-08-15)

Implemented test-first. Governance landed the additive `agent/v1` enrolment/rotation messages at
**5e33e90** and the authz role entries at **2c268d3** (owner-only `agent.enrolment_token.issue` /
`agent.enrolment_token.revoke` / `agent.dataplane.revoke` / `agent.dataplane.read`; policy bundle
0.9.0), both merged to governance main. Backend merged to main at **8e5d013**. Every criterion is
proven by named tests at that pin; nothing here needed a live cluster, so this record is unsplit —
the phase-level "whole path on a real customer-shaped cluster" criterion belongs to the plan's exit,
not to this task.

**AC1–AC9, one line of proof each (backend@8e5d013):**

- **AC1** — token single-use proven including the spent-then-failed path: a retry after a partial
  enrolment that failed *after* the token was spent is refused, never mints a second identity.
- **AC2** — token secrecy asserted by test: no enrolment token reaches a log line, error message,
  metric label, or install-written artifact.
- **AC3** — identity comes from the issued certificate; a payload claiming another tenant/data
  plane/role is ignored *and* produces an audited override refusal.
- **AC4** — rotation runs on the channel the agent already holds, proven across a certificate
  boundary (old cert out, new cert in, stream survives).
- **AC5** — a revoked or expired certificate is refused on the next connection attempt; revocation
  needs no access to the customer's cluster.
- **AC6** — no degraded mode: a data plane with neither a valid certificate nor an unspent token
  stays disconnected.
- **AC7** — exactly one audit record per lifecycle act — enrolment, issuance, rotation, revocation —
  including refused connections.
- **AC8** — stale is a distinct state and is never rendered as healthy.
- **AC9** — cross-tenant isolation on the agent surface: coarse refusals indistinguishable from
  nonexistent records.

**Recorded limits:**

- **Stores are in-memory.** ~~The enrolment-token and data-plane-registry stores do not survive a
  control-plane restart; Postgres adapters are future work (tracked in `../backlog/`).~~
  **Closed 2026-08-16 by T-0036** (SPEC-0042 AC1/AC2, backend@c9e58c5): both stores are durable
  Postgres state and the restart proofs run against a real database.
- **CA key custody is dev custody.** ~~The enrolment CA's key custody is the platform-secrets question
  SPEC-0038's out-of-scope names; production custody is deferred to the ADR-0057-scoped custody
  follow-up (tracked in `../backlog/`).~~ **Closed 2026-08-16 by T-0040** (SPEC-0044, ADR-0064/0066):
  the CA signs through an OpenBao custody seam holding key references only, the production
  composition root cannot construct a CA from disk or env, and staged rotation is proven with no
  re-enrolment. The custody-enabled control-plane **image** is a separate matter and is still open —
  see T-0040's own recorded limits.
- **Proxy-only egress stays open** (ADR-0017's remaining follow-up) — a customer behind an
  HTTP-proxy-only egress still cannot install.
- **Clock-skew runbook entry still owed.** ~~The symptom (a skewed customer cluster presents as a
  network fault) is named in SPEC-0038's non-functional but not yet in `deploy/MVP-RUNBOOK.md`; the
  cluster-lane runbook pass owns it.~~ **Closed 2026-08-16 by T-0040** (SPEC-0044 AC4): the entry is
  `deploy/MVP-RUNBOOK.md` §4a, and `scripts/check-runbook.sh` gates its presence and the §6b
  cross-reference that resolves to it — the gate asserts it on every `make verify`.
