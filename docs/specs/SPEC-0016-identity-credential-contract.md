# SPEC-0016: Identity credential authentication contract

- **Status:** Approved
- **Owner:** platform
- **Context(s):** Identity&Access
- **ADRs:** 0003, 0006, 0022, 0041
- **Task(s):** T-0013; T-0011 (consumer)

## Problem / context

SPEC-0006 requires tenant-scoped identities, PATs and SSH keys, while ADR-0041 requires the Git
front doors to obtain a verified principal before routing any operation to `GitStorage`. Neither
document defines the wire shape that turns a PAT or verified SSH public-key proof into that
principal. Without a contract, the two front doors would independently decide token parsing,
tenant selection, revocation behavior and what data reaches the PDP.

## In scope

- An additive `contracts/proto/identity/v1/identity.proto` package for the internal
  Identity&Access authentication port.
- `CredentialAuthenticator.AuthenticatePAT` and `CredentialAuthenticator.AuthenticateSSHKey`, each
  returning a tenant-scoped `Principal` only after the credential is valid and active.
- `Principal` contains stable `tenant_id`, `actor_id`, and roles. It carries no raw credential,
  session material, email address, repository handle, authorization decision, or storage path.
- PAT issue, list and revoke request/response shapes. Issuance returns a plaintext secret exactly
  once; persisted state holds only a keyed one-way verifier and token metadata. Revocation takes
  effect before the next authentication decision.
- Coarse denial semantics: malformed, expired, revoked, unknown and cross-tenant credentials return
  no principal and one non-enumerating denial class. Authentication failure occurs before any
  repository route, `GitStorage` call, or PDP decision for the requested repository.
- Every successful Git operation still makes the PDP decision in `git-storaged` under ADR-0041;
  authentication supplies identity, never an `allowed` assertion.

## Out of scope

- OIDC browser session endpoints, SAML and SCIM provisioning UI; T-0013 may add adapters after this
  contract, but these are not Git credential messages.
- Organization membership management and fine-grained role UI.
- Passing credentials over `GitStorage`, the agent stream, events, audit records, telemetry, logs or
  browser-visible repository APIs.

## Contracts touched

`contracts/proto/identity/v1/identity.proto` is additive and contains:

- `CredentialAuthenticator.AuthenticatePAT` and `AuthenticateSSHKey`;
- `Principal { tenant_id, actor_id, repeated roles }`;
- `IssuePAT`, `ListPATs`, and `RevokePAT` lifecycle messages with opaque token IDs and scope labels;
- one response shape whose default/empty result is denial and contains no credential or repository
  existence detail.

Exact field numbers and generated-language package paths are part of the contract implementation PR,
after this specification is Approved and under the v1 additive-only rule.

## Data owned

Identity&Access owns credential metadata, keyed verifiers, revocation state, SSH key fingerprints,
and the tenant-scoped principal mapping. Repository/Git owns no credential state and receives only a
verified principal's IDs through the front door; Policy owns authorization decisions.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A valid scoped PAT authenticates to a tenant-scoped principal; the plaintext token is
  returned only at issuance and never stored, logged, emitted, or returned again.
- [ ] AC2: A verified SSH key authenticates to the same principal shape; an unknown, revoked, or
  cross-tenant key returns the same coarse denial as an invalid PAT.
- [ ] AC3: Missing or failed authentication opens no GitStorage stream and makes no repository PDP
  request. A successful authentication cannot assert authorization; `git-storaged` still asks PDP.
- [ ] AC4: Revoking a PAT or SSH key denies its next use, and token/identity lookup is tenant-scoped.
- [ ] AC5: The generated contract exposes no filesystem path, repository ID, authorization result,
  raw credential in a response **except `IssuePATResponse.plaintext_token` at issuance exactly
  once**, or agent-stream-compatible credential field. Authentication, list, revoke, events and
  agent messages never return raw credentials.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | authentication returns an identity bound to one tenant; cross-tenant credentials are indistinguishable denials |
| G2 least privilege | authentication is distinct from PDP authorization; no caller-provided allow result exists |
| G5 auditability | credential lifecycle can emit bounded first-party events without secrets |
| G9 least-privilege footprint | credential data stops at the Identity&Access port and never crosses GitStorage or agent wires |

## Non-functional

- Authentication is O(1) on the Git hot path and safe under concurrent revocation.
- Token verifier comparison is constant-time; plaintext credentials are redacted before any error,
  metric, trace, or audit serialization.
- The front doors stream Git bytes without retaining a pack while authentication remains a bounded
  preflight operation.

## Open questions / assumptions

- The concrete Zitadel OIDC/SAML/SCIM adapter and tenant provisioning mapping remain T-0013 adapter
  work. This contract needs only a stable principal result and does not make an IdP-specific wire
  choice.
- PAT scope vocabulary is policy data; message fields carry labels but clients do not derive
  authorization from them. A new scope requires an additive policy/contract review.
