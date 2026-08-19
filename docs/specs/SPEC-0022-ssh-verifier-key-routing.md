# SPEC-0022: SSH verifier-key routing

- **Status:** Implemented (2026-08-10) — every acceptance criterion is proven by its task(s)
- **Owner:** platform
- **Context(s):** Identity&Access + Repository/Git front doors
- **ADRs:** 0003, 0006, 0022, 0041, 0043
- **Task(s):** T-0013; T-0011 (consumer)

## Problem / context

ADR-0043 requires every opaque credential lookup to use a public verifier key ID and an indexed
`(credential_kind, key_id, verifier)` tuple. `AuthenticateSSHKeyRequest` currently contains only
the verified public key, so a rotating HMAC key ring would have to probe every old key to find a
match. That is neither O(1) nor an acceptable authentication hot path.

## In scope

- Add an additive `verifier_key_id` field to `AuthenticateSSHKeyRequest` in
  `contracts/proto/identity/v1/identity.proto` after this specification is Approved.
- Require the SSH front door to select that non-secret ID from its configured Identity&Access
  verifier-key-ring configuration; it is never supplied as a tenant, actor, repository, role, or
  authorization assertion.
- Resolve a verified public key only through the ADR-0043 tuple and return the existing
  tenant-scoped `Principal` on success.
- Treat a missing, unknown, retired, malformed, revoked, expired, inactive, or cross-tenant
  credential as the existing empty-principal coarse denial.

## Out of scope

- A new SSH transport, key proof format, key-registration/revocation lifecycle surface, or a
  change to the principal, PDP, GitStorage, agent, audit-event, or browser contracts.
- HMAC key material, key-custody implementation, or the per-environment rotation runbook.

## Contracts touched

After approval, add `string verifier_key_id` to `AuthenticateSSHKeyRequest` with a new v1 field
number. The field is request-only, contains no secret and no tenant meaning, and is never copied
to a response, event, audit detail, log, metric, trace, or agent message.

## Data owned

Identity&Access owns the key-ID/verifier index and resolves it through the ADR-0043 read-only RLS
gateway. Repository/Git owns front-door configuration and forwards only the configured key ID plus
the SSH transport's already-verified public-key proof. Policy remains the authorization owner.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A valid verified SSH key with an active configured verifier key ID returns the existing
  tenant-scoped principal through one indexed lookup.
- [ ] AC2: Missing, unknown, retired, malformed, revoked, expired, inactive, and cross-tenant SSH
  credentials return the same empty-principal denial shape and reveal no lookup detail.
- [ ] AC3: Two active key IDs can authenticate credentials issued under their respective keys
  without probing another key; retiring a key denies its credentials on the next lookup.
- [ ] AC4: The request, response, agent, audit, and logging surfaces contain no key material,
  verifier, tenant-routing claim, repository handle, or authorization assertion.
- [ ] AC5: Authentication succeeds before GitStorage routing but does not replace its PDP decision.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | an opaque credential lookup returns only an active tenant-bound principal |
| G2 least privilege | key ID selects an Identity-owned verifier key, never an authorization or tenant claim |
| G5 auditability | key material and verifiers remain excluded from bounded credential audit entries |
| G9 least-privilege footprint | only a public key ID and verified public-key proof reach the authentication port |

## Non-functional

- The key-ID parse and verifier lookup are O(1) regardless of the number of active or retired
  keys.
- Verifier comparisons remain constant-time and revocation/retirement affect the next lookup.
- The front door obtains the key ID from per-environment configuration, never from an SSH client
  tenant claim (invariant 13).

## Open questions / assumptions

- The key ID is a public configuration selector, not an SSH-key property. Its distribution to
  front doors is part of the per-environment key-custody/rotation runbook required by ADR-0043.
- The additive proto field and generated stubs follow in a separate contract PR after approval.
