# ADR-0046: Platform-operator principals authorize replica force-promotion

- **Status:** Accepted
- **Date:** 2026-08-10
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege, G5 auditability
- **Refines:** ADR-0006, ADR-0018, ADR-0042
- **Tasks:** T-0012

## Context

ADR-0018 and ADR-0042 make dual-loss recovery operator-only: a stale async replica must never
auto-promote, and accepting its possible RPO loss requires a PDP decision and immutable audit
evidence. SPEC-0018 consequently requires `replica.force_promote`, but the current policy
vocabulary has only tenant membership roles. It does not identify a principal that may act for the
platform in one tenant, nor does it say how that authority stays unavailable to tenant users.

Using a tenant owner would make a durability-loss decision tenant self-service, which ADR-0042
rejects. Bypassing the PDP for a global service identity would violate deny-by-default and leave no
tenant-scoped authorization record. The force-promotion contract and implementation must not pick
one of those models implicitly.

## Decision

We will authorize force-promotion with a verified, tenant-scoped **platform-operator** principal.

1. Identity&Access maps an authenticated platform operator to the `platform_operator` role only
   through a platform-administered tenant binding. Tenant membership management and browser input
   cannot create, grant, or modify that binding.
2. The Policy PDP grants `replica.force_promote` on a `repository_shard` resource only to that
   role, with the principal tenant equal to the shard tenant. The PEP derives tenant, actor, and
   roles from the verified identity; request payloads carry neither an `allowed` flag nor a role
   assertion.
3. The replica coordinator records the PDP-issued decision ID, verified actor ID, tenant-scoped
   shard identity, selected replica, estimated RPO window, and old/new fencing terms in the one
   immutable `replica.force_promote` audit event after a successful fence and CAS.
4. This role authorizes only the recovery action. It gives no repository read/write, tenant
   administration, credential, or policy-authoring grant. Break-glass identity issuance and
   operator UI/runbook mechanics remain separate work; an unavailable or unverified operator
   identity is a denial and leaves the shard read-only.

## Consequences

**Positive:** the RPO-loss decision stays platform-controlled, PDP-mediated, tenant-scoped, and
auditable; the existing policy contract and tenant-equality invariant remain intact.

**Negative / costs:** Identity&Access must represent platform-administered bindings distinctly
from tenant-managed membership, and recovery cannot proceed while that verification path is
unavailable.

**Follow-ups:** after acceptance, add the reviewed policy rule and tests, define the additive
replica coordination contract, then implement T-0012's CAS, fence, audit, and kill-node tests.

## Alternatives considered

- **Tenant owner force-promotion** — rejected: it is tenant self-service for an acknowledged-data
  loss decision, contrary to ADR-0042.
- **Global operator identity that bypasses the PDP** — rejected: it violates invariant 2 and does
  not produce a tenant-scoped policy decision.
- **Automatic promotion of an async replica** — rejected by ADR-0018: an asynchronous replica can
  lack an acknowledged push.
