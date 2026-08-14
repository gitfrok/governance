# SPEC-0038: Agent enrolment and data-plane self-registration

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** Control plane (issues, registers, revokes) · Agent (dials out) — ADR-0022
- **ADRs:** 0060 (decides identity), 0009, 0010, 0011, 0013, 0017
- **Task(s):** T-0030

## Problem / context

PR-20: a customer installs the data plane into their own GKE/EKS/AKS and it self-registers over an
outbound-only connection. `contracts/proto/agent/v1` defines `AgentGateway.Connect` and nothing
implements it. ADR-0060 fixes how the agent gets its identity — a one-time enrolment token, then
control-plane-issued short-lived certificates rotated on the channel.

This spec fixes the enrolment surface, the registration handshake, and the states an operator has to
be able to see and act on. It is the first thing Phase 3 needs: nothing else in the phase can be
delivered to a data plane that cannot connect.

## In scope

- Enrolment token issuance, single use, expiry, and revocation.
- The first `Connect`: token presentation, certificate issuance, data-plane record creation.
- Certificate rotation over the established stream, and what happens when it does not happen in time.
- Revoking a data plane, and the disconnected/never-connected/revoked states an operator sees.
- The audit records all of the above produce.

## Out of scope

- What flows over the stream once connected — desired state, telemetry, upgrades (SPEC-0039,
  SPEC-0041).
- Helm/Operator packaging and per-cloud drivers (SPEC-0039).
- HTTP/2 proxy fallback for restricted egress — ADR-0017's remaining open follow-up.
- The CA's own key custody, which is the platform-secrets question ADR-0057 also carries.

## Contracts touched

`contracts/proto/agent/v1` — **additive only**: enrolment and certificate-rotation messages within
the existing `AgentMessage`/`ControlPlaneMessage` envelopes. No existing field changes meaning, and
`AgentGateway.Connect` stays the single RPC (ADR-0017).

## Data owned

The control plane owns enrolment tokens, issued certificates, and the data-plane registry (tenant,
data-plane ID, cloud, region, version, last-seen). The customer's cluster owns nothing about its own
identity beyond the certificate it was issued.

## Acceptance criteria (each becomes a test)

- [ ] AC1: An enrolment token is single-use, tenant-scoped and time-bounded. A second presentation is
  refused and audited, including when the first attempt failed after the token was spent — a retry
  after a partial enrolment must not silently mint a second data-plane identity.
- [ ] AC2: A token never appears in a log line, an error message, a metric label, or any file the
  install writes back (Helm values, ConfigMap, CR status). Asserted by test, not by review.
- [ ] AC3: A successful first `Connect` yields a client certificate naming the tenant and the data
  plane, and a registry record. Every subsequent message on that stream is attributed to the
  certificate's identity; a payload field claiming another tenant, data plane or role is ignored and
  audited (invariant 2 on the agent wire).
- [ ] AC4: Certificates rotate over the established stream before expiry, with no operator step and
  no second endpoint. A rotation that fails is retried, surfaced, and — if the certificate expires —
  the connection is refused rather than extended.
- [ ] AC5: An expired or revoked certificate cannot connect. Revocation takes effect on the next
  connection attempt and needs no access to the customer's cluster.
- [ ] AC6: A data plane that cannot present a valid certificate and holds no unspent token stays
  disconnected. There is no degraded mode that accepts an unidentified data plane (ADR-0060 §4).
- [ ] AC7: Enrolment, issuance, rotation, revocation and refused connections each append exactly one
  immutable audit record naming tenant, data plane, actor where there is one, and outcome.
- [ ] AC8: Operator visibility: never-connected, connected, stale (no contact within a configured
  window), and revoked are distinguishable in the control plane, and a stale data plane is never
  rendered as healthy.
- [ ] AC9: Cross-tenant isolation holds on the agent surface: a certificate issued for tenant A can
  neither read nor write anything of tenant B's, and a refusal is the same coarse shape as a
  nonexistent record (SPEC-0001).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | identity is tenant-bound in the certificate; payload claims never override it (AC3, AC9) |
| G2 authorization | connection admission is a control-plane decision; no self-asserted identity (AC3, AC6) |
| G3 auditability | one immutable record per lifecycle act, including refusals (AC7) |
| G7 residency | the registry records cloud and region, feeding SPEC-0040's pinning evidence |
| G9 operability | enrolment is one command; staleness and revocation are visible states (AC8) |

## Non-functional

- Certificate lifetime and the staleness window are per-environment configuration (invariant 13).
- Clock skew in the customer's cluster is a first-class failure mode: short-lived certificates plus a
  skewed clock disconnect a healthy data plane, and the runbook must name the symptom because it
  will present as a network fault.

## Open questions / assumptions

- Proxy-only egress is unaddressed (ADR-0017 follow-up); a customer behind an HTTP-proxy-only egress
  cannot install until it is.
- Assumed: one agent per data plane, one data plane per tenant per cluster. Multiple data planes for
  one tenant is not refused by anything here, but nothing depends on it either.
