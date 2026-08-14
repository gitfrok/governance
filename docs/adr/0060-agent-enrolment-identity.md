# ADR-0060: A data-plane agent's identity comes from a one-time enrolment token and control-plane-issued certificates

- **Status:** Accepted (2026-08-14)
- **Deciders:** platform
- **Supersedes / superseded by:** —
- **Related:** ADR-0011 (outbound-only agent), ADR-0017 (agent gRPC/mTLS protocol — this closes its
  cert-issuance follow-up), ADR-0009, ADR-0010, ADR-0013, SPEC-0038, T-0030

## Context

ADR-0011 fixes the connection direction — the data plane dials out, the control plane never dials in
— and ADR-0017 fixes the transport as gRPC over mTLS with `contracts/proto/agent/v1`'s
`AgentGateway.Connect`. Neither says where the agent's client certificate comes from, and ADR-0017
carried "cert issuance and rotation (SPIFFE/SPIRE) + HTTP/2 proxy fallback" as an open follow-up.

That gap blocks PR-20. A data plane that self-registers has to prove which tenant it belongs to
before it has any credential at all, and an outbound-only design means the control plane cannot go
and check.

The install runs in a cluster we do not operate, on GKE, EKS or AKS (ADR-0010). Anything we require
inside that cluster becomes something the customer runs and we support, three times over.

## Decision

**A one-time enrolment token bootstraps; the control plane issues and rotates short-lived client
certificates over the connection the agent already holds.**

1. **Enrolment.** The customer installs with a token issued by the control plane for one tenant, one
   use, with an expiry. The agent presents it on its first `Connect`, receives a client certificate,
   and the token is spent — a replay after that is refused and audited, whether or not the first use
   succeeded.
2. **Rotation happens on the channel.** The control plane issues the next certificate before the
   current one expires, over the established stream. There is no second endpoint, no inbound path,
   and no operator step in the normal case.
3. **The certificate names the tenant and the data plane**, and nothing the agent asserts overrides
   it. A message arriving on a stream is attributed to the identity in the certificate — the agent
   cannot claim another tenant's ID in a payload field (invariant 2's shape, applied to the agent
   wire).
4. **Loss of the certificate is recoverable only by re-enrolment.** A data plane that cannot present
   a valid certificate and has no unspent token stays disconnected until an operator issues a new
   token. There is no fallback that trades identity for availability.
5. **Revocation is a control-plane act.** Revoking a data plane's identity refuses its next
   connection and is audited; it does not require reaching into the customer's cluster.

**Rejected: SPIFFE/SPIRE in the customer cluster.** Stronger attestation and a standard auditors
recognize, but it puts a second distributed system in every install, across three managed
Kubernetes flavours, for a trust improvement over a token whose blast radius is already one tenant
and one use. Revisit if a customer's own attestation requirements demand it — this ADR does not
foreclose it, and the certificate contract stays the same either way.

**Rejected: per-cloud workload identity** (GKE Workload Identity / EKS IRSA / AKS Workload Identity).
No extra infrastructure, but three provider paths to build, keep conformant and reason about, and it
puts cloud-specific claims inside the trust model that ADR-0010's portability layer exists to keep
out.

## Consequences

- ADR-0017's cert-issuance follow-up closes. **The HTTP/2 proxy-fallback half stays open** — a
  customer whose egress only permits an HTTP proxy still has no answer, and that is now the only
  remaining piece of that follow-up.
- The control plane gains a certificate authority role for agent identities: issuance, rotation,
  revocation and their audit records. SPEC-0038 owns the surface; the CA's own key custody is a
  platform-secrets question shared with ADR-0057's follow-up.
- An enrolment token is a bearer credential until it is spent. It must never be logged, echoed into
  an error, or written into a Helm values file that lands in a customer's Git repository — SPEC-0038
  AC2 exists to make that testable rather than advisory.
- Time skew becomes an operational failure mode: short-lived certificates and a badly-skewed cluster
  clock disconnect a healthy data plane. The runbook needs the symptom, because it will read as a
  network fault.
