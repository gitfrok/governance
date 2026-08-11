# ADR-0049: The browser session is an opaque server-side cookie the BFF owns

- **Status:** Accepted
- **Date:** 2026-08-10 · **Accepted:** 2026-08-12
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege, G5 auditability
- **Refines:** ADR-0045 (Zitadel tenant/principal mapping), ADR-0015 (BFF boundary)
- **Relates to:** ADR-0020, ADR-0022, ADR-0023 · **Specs:** SPEC-0006, SPEC-0021
- **Invariants:** 1 (tenant scoping), 2 (PDP authorization)
- **Tasks:** T-0013, T-0015, T-0016 (the MR views need the same session)

## Context

ADR-0045 settled how an OIDC login becomes a tenant-scoped principal. It did not settle what the
browser holds afterwards, and the Phase-1 plan records that gap as an open decision — one that
ripples through every browser-facing surface, because SPEC-0021 requires the BFF to derive its
`ReadContext` "only from authenticated request/session middleware".

The BFF's browser view handlers now exist and define the port they need. Nothing satisfies it, and
nothing can until this is decided, so T-0015's web half and T-0016's MR views are both blocked
behind it.

Three shapes were considered.

**A bearer token in `Authorization`, held in JavaScript.** Conventional for an SPA and trivial to
forward. It also means the credential is reachable from any script on the page: one injection, one
dependency with a compromised build, and it is exfiltrated. The web frontend is server-rendered
(ADR-0020) and does not need a credential in JavaScript to function, so this pays that price for
nothing.

**A self-contained signed token in a cookie (JWT session).** No session store, and verification is
local. The cost is revocation: a signed token is valid until it expires, so "log out", "remove this
user", and "this tenant is suspended" are all requests the system cannot honour promptly. SPEC-0006
explicitly requires that session revocation propagates promptly. Short expiry plus refresh narrows
the window without closing it, and adds a refresh path that is itself a credential.

**An opaque identifier in a cookie, resolved server-side.** Revocation is a delete. The browser
holds a value that means nothing anywhere else, and the tenant, actor and roles never leave the
server. The cost is a lookup on every request and a store to keep.

## Decision

We will identify a browser session by an **opaque, high-entropy identifier in a cookie**, resolved
by the BFF against a server-side session store on every request.

1. **The cookie is `__Host-gitfrok_session`, `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`.** The
   `__Host-` prefix binds it to the exact origin with no `Domain` attribute, so a sibling subdomain
   cannot set or read it. `HttpOnly` keeps it out of JavaScript; `SameSite=Lax` allows the top-level
   navigation an OIDC redirect performs while refusing cross-site sub-requests.

2. **The identifier is opaque and carries no claims.** At least 256 bits from a cryptographic
   source. It is a lookup key and nothing else: tenant, actor, roles and expiry live in the store,
   so a browser cannot read them and cannot alter them.

3. **The BFF resolves it to a `ReadContext` on every request and forwards that.** No handler reads
   a cookie, and no browser input contributes a tenant, actor, role, or authorization outcome
   (SPEC-0021). A request with no session, an unknown session, or an expired one is refused as
   unauthenticated, and that refusal says nothing about what exists.

4. **Revocation is deletion, and it is immediate.** Logout, an administrative revocation, and a
   tenant suspension each delete the record; the next request has no session. This is the property
   the signed-token alternative could not provide, and SPEC-0006 requires it.

5. **The session store is Valkey** (ADR-0023), keyed by the identifier, with a server-side absolute
   expiry and an idle timeout. It is not Postgres: a session is high-churn, short-lived, and its
   loss logs people out rather than losing data.

6. **The session records the tenant it was issued for, and that binding is immutable.** A session
   cannot be re-pointed at another tenant; switching tenants is a new login. This is what keeps
   invariant 1 true for every browser-facing read.

7. **The OIDC exchange happens once, at the callback.** The BFF calls Identity&Access
   `ExchangeCode`, receives a principal, and creates a session from it. The ID token, the
   authorization code, and the PKCE verifier are never stored and never returned to the browser.

8. **Roles are captured at login and re-read from the store, not from the browser.** A role change
   takes effect at the next login or at whatever refresh a later ADR defines; a browser can never
   assert one. Deciding refresh is deliberately deferred — this ADR fixes where roles live, not how
   often they are re-fetched.

## Consequences

**Positive.** Revocation actually works. No credential is reachable from JavaScript, so an injected
script cannot steal a session. Tenant, actor and roles never cross the boundary to the browser, so
there is nothing there to tamper with, and SPEC-0021's "identity from the session alone" becomes
enforceable rather than aspirational.

**Negative / costs.** Every browser request needs a store lookup, which puts Valkey on the critical
path for the web surface: if it is down, the web app is logged out even though the API is healthy.
Sessions are now state to operate — sized, expired, and monitored. And a cross-origin API client
cannot use this session; a programmatic caller uses a PAT, which is what PATs are for.

**Neutral.** CSRF becomes a concern that `SameSite=Lax` mitigates but does not by itself close for
state-changing requests. The MR write surface (T-0016) must carry a CSRF defence, and it is called
out here so that it is designed rather than discovered.

## Open questions

- Whether roles are refreshed mid-session and how. Fixed here: roles live server-side. Not fixed:
  their staleness bound.
- The CSRF mechanism for browser-initiated writes, due with T-0016's web half.
