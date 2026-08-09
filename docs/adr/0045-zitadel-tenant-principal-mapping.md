# ADR-0045: Zitadel verified claims map to tenant-scoped principals

- **Status:** Proposed
- **Date:** 2026-08-10
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege, G5 auditability
- **Relates to:** ADR-0003, ADR-0006, ADR-0023, ADR-0043 · **Task:** T-0013

## Context

T-0013 requires OIDC login to yield a tenant-scoped principal.
Zitadel supports organization, project-role, discovery, and JWK claims.
Claim selection and tenant mapping are security boundaries.
Browser-supplied tenant or unverified profile claims would bypass RLS and PDP assumptions.

## Decision

We will use Zitadel Authorization Code Flow with PKCE.
The Identity&Access adapter discovers keys only from the configured issuer.
It validates ID-token signature, issuer, audience, `azp`, expiry, not-before, nonce, and code-verifier.
Every validation failure returns the existing coarse denial.

The verified `sub` becomes the stable actor ID.
The verified `urn:zitadel:iam:user:resourceowner:id` claim becomes the tenant ID after an Identity-owned active tenant-mapping check.
The mapping is one-to-one and tenant-scoped.
A missing claim or inactive mapping creates no principal or session.

Only roles from the verified configured Zitadel project-role claim enter the principal.
The adapter permits an explicit reviewed role vocabulary and ignores unknown roles.
Browser input, organization scope, redirect parameters, and session cookies never choose tenant, actor, roles, or authorization outcome.
SAML and SCIM write the same Identity-owned actor/tenant/membership model after provider verification.

Issuer, client ID, redirect URI, audience, role-claim name, and allowed role vocabulary are per-environment configuration.
No production value is compiled into a binary or contract.

## Consequences

**Positive:** tenant, actor, and roles arrive from one verified identity source.
OIDC, SAML, SCIM, PAT, and SSH converge on one principal shape.
RLS and PDP receive no browser-selected tenant assertion.

**Negative / costs:** Zitadel project and organization setup is a deployment prerequisite.
A bad mapping fails closed.
Role-vocabulary changes require governance and policy review.

**Follow-ups:** T-0013 adds OIDC adapter, mapping persistence, callback/session tests, and opaque-ID audit entries.
The BFF/web task consumes that session and never reads Zitadel claims directly.

## Alternatives considered

- **Browser-supplied tenant or organization scope** — rejected: it is an unauthenticated routing claim.
- **Email domain as tenant identity** — rejected: domains and aliases are not stable authorization boundaries.
- **Trust any custom role claim** — rejected: unconfigured claims silently widen privilege.
- **Separate OIDC, SAML, SCIM principal formats** — rejected: consumers need provider-specific authorization logic.
