# T-0030: Agent enrolment, self-registration, and certificate rotation

- **Status:** Todo
- **Phase / Epic:** 3 / EP-15 (BYO data plane)
- **Repo(s):** governance (additive `agent/v1` messages first, ADR-0027 order), then backend
- **Spec:** docs/specs/SPEC-0038-agent-enrolment-registration.md (Draft — Approved before RED)
- **ADRs:** 0060, 0011, 0017, 0009, 0010
- **Owner:** unassigned

## Goal
Implement `AgentGateway.Connect`'s enrolment half: a one-time token brings a data plane up, the
control plane issues and rotates its certificate on the channel, and an operator can see and revoke
it. Nothing else in Phase 3 can be delivered to a data plane that cannot connect.

## Acceptance criteria (test-first)
SPEC-0038 AC1–AC9. The ones most likely to be faked, called out:
- [ ] AC2: no token in any log, error, metric label, or file the install writes back — asserted by
      test, not by review.
- [ ] AC3: identity comes from the certificate; a payload claiming another tenant is ignored *and*
      audited.
- [ ] AC6: no degraded mode that accepts an unidentified data plane.
- [ ] AC8: stale is distinguishable from healthy, and never rendered as healthy.

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
