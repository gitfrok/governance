# ADR-0043: Resolve opaque credential verifiers through a narrow RLS gateway

- **Status:** Proposed
- **Date:** 2026-08-09
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege, G5 auditability, G9 least-privilege footprint
- **Relates to:** ADR-0003 (shared Postgres + RLS), ADR-0006 (PDP), ADR-0022 (context ownership),
  ADR-0041 (Git front doors), SPEC-0006, SPEC-0016 · **Tasks:** T-0013, T-0011

## Context

Identity&Access must authenticate a PAT or SSH key before a Git front door has a tenant context
(ADR-0041). Persisted credential rows are tenant-owned and protected by ADR-0003 row-level
security, so ordinary application queries correctly require a tenant setting. A global application
role or an unscoped `SELECT` to find a verifier would make all tenant credentials readable to every
caller and defeats the RLS boundary. Requiring the client to send a tenant hint would turn an
opaque credential into a tenant-discovery interface and still leaves an attacker-controlled routing
claim before authentication.

The lookup must stay O(1), return only a verified tenant-scoped principal, take effect immediately
on revocation, and never persist or expose a plaintext credential. It also needs a rotation path
that does not turn one HMAC key into an unbounded hot-path search.

## Decision

We will resolve an unauthenticated credential only through one narrow, reviewed
Identity&Access database gateway:

1. **Persist only keyed credential verifiers.** PAT secrets and SSH public-key fingerprints are
   normalized by Identity&Access, then HMACed with a service-held key before persistence or lookup.
   Raw credentials, raw SSH public keys, and reversible encrypted equivalents are never stored in
   the credential index, audit trail, events, metrics, errors, or traces.

2. **Give each credential an authenticated format version/key ID.** A PAT's public prefix selects
   one active verifier key; the remaining secret is HMACed with that key. The key ID is not a
   credential and has no tenant meaning. The resulting lookup key is `(credential_kind, key_id,
   verifier)` with a unique index, so the hot path remains O(1). Key rotation introduces a new key
   ID while old keys remain available only for credentials issued under them until expiry or
   explicit revocation; retiring a key revokes its remaining credentials rather than requiring a
   scan of plaintext that does not exist.

3. **Use one `SECURITY DEFINER` read-only resolver, not an RLS bypass in application code.** The
   migration-owned `identity.resolve_active_credential(kind, key_id, verifier)` has a fixed,
   schema-qualified query and a safe fixed `search_path`; it returns zero or one principal tuple:
   tenant ID, actor ID, and active verified roles. It filters credential kind, key ID, verifier,
   revoked state, expiry, tenant/principal activity, and membership activity before returning.
   It has no dynamic SQL, no caller-supplied table/column/path, no mutation, and no raw credential
   output. Application roles receive `EXECUTE` on this function only; they receive no unscoped
   `SELECT` on identity credential tables.

4. **Restore normal tenant scope immediately after resolution.** The application treats a zero-row
   result and every resolver error as one coarse authentication denial. A principal result creates
   the tenant-scoped request context used by all later RLS transactions and PDP calls. Repository,
   GitStorage, BFF, and browser code receive only that verified principal; no resolver handle or
   credential verifier crosses the Identity&Access boundary.

5. **Keep authentication distinct from authorization and auditing.** Resolver success proves only
   credential ownership. The existing PDP still decides every protected action, including the
   storage-layer Git decision. Credential lifecycle and authentication outcome audit entries carry
   opaque credential/principal IDs and request correlation only, never a verifier, key ID tied to
   a secret, raw credential, or tenant-existence detail.

6. **Prove the privilege boundary, not only the happy path.** Migration and integration tests must
   show that the normal app role cannot globally select credential rows; the resolver cannot return
   revoked, expired, inactive, or cross-tenant state; malformed/unknown credentials are coarse
   denials; and a revocation is effective on the very next lookup. A boundary test must reject any
   direct credential-table query outside the Identity&Access adapter.

OIDC/SAML callback state already has a signed, configured tenant route and uses ordinary
tenant-scoped identity writes after provider verification. SCIM provisioning likewise operates with
an established tenant administration context; neither is an unauthenticated global verifier lookup.

## Consequences

**Positive.** Opaque Git credentials can establish their one required tenant/principal context
without weakening RLS for every application query. The one elevated database capability is narrow,
read-only, testable, and owned by Identity&Access. Key ID routing preserves O(1) lookup across key
rotation, while immediate revocation remains a single indexed state check.

**Negative / costs.** `SECURITY DEFINER` is privileged code and must be migration-reviewed as a
security boundary. The HMAC key ring needs protected configuration, rotation and retirement
operations. Existing credentials on a retired key must be explicitly revoked/reissued, which is an
intentional availability trade-off for keeping an opaque verifier non-reversible.

**Follow-ups.**

- T-0013 adds the tenant-RLS migration, resolver adapter, issuance/revocation transactions,
  bounded audit emission, and key-ring configuration/tests.
- T-0011 consumes the verified principal only through the Identity&Access port, as ADR-0041
  requires.
- The key-custody location and operational rotation runbook are per-environment security
  configuration; they must be documented before production issuance is enabled.

## Alternatives considered

- **Unscoped application `SELECT` or service-role bypass** — rejected. It makes a transient
  unauthenticated request able to read a cross-tenant credential index and erases ADR-0003's
  defense-in-depth boundary.
- **Client-supplied tenant hint in an opaque PAT or SSH request** — rejected. It is unauthenticated
  routing input, exposes tenant shape unnecessarily, and does not make a global lookup safe.
- **Scan every tenant-scoped credential table or every old HMAC key** — rejected. It violates the
  O(1) hot-path requirement and gives revocation/rotation an unbounded latency tail.
- **Store reversible encrypted credentials** — rejected. It expands the secret-bearing surface
  without improving verification; keyed one-way verifiers are sufficient.
