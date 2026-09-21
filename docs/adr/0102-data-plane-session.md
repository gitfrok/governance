# ADR-0102: A data-plane deployment authenticates for itself, against the same issuer

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (requested by the deciding owner)
- **Amends:** **ADR-0093's component partition in one respect** — Valkey becomes bi-planar. That
  table placed it control-plane-side only, on the premise that the BFF was control-plane-side only,
  which ADR-0094 decision 3 has since changed. ADR-0093 is Accepted and is not edited (ADR-0001).
- **Related:** ADR-0094 (decisions 3 and 6 — the data-plane repository surface and URL navigation),
  ADR-0100 (decision 1 moved `OIDCLogin` control-side), ADR-0101 (decision 2's bi-planar schemas and
  their disjoint rows — the reason the obvious answer fails), ADR-0011 (direction: a data plane may
  reach out; a control plane may not reach in), ADR-0043 (the PAT credential model), ADR-0045
  (Zitadel as the OIDC issuer), ADR-0049/0052 (the BFF's browser session and its store), ADR-0095
  (`auth-gitfrok` is a public issuer with its own hostname), SPEC-0070 (blocked on this for AC6)
- **Governs:** G1 isolation, G6 compliance

## Context

SPEC-0070 partitioned the BFF's routes and left one thing unresolved that no amount of routing fixes:
**a data-plane deployment can be routed correctly and still authenticate nobody.** Three accepted
decisions produce it together — ADR-0093 put Valkey, the session store ADR-0052 requires, on the
control plane only; ADR-0100 decision 1 moved `OIDCLogin` control-side; and ADR-0011 forbids a
data-plane process reaching into the control plane for either.

**The obvious answer does not work, and it is worth writing down why.** Both planes already carry the
same `gitfrok-pat-verifier` key, which suggests a control-plane-issued credential verified
data-plane-side with no shared store. But ADR-0043 resolves a credential "only through one narrow,
reviewed Identity&Access **database** gateway": a PAT's prefix selects a verifier key and the lookup
is `(credential_kind, key_id, verifier)` **against the identity schema**. ADR-0101 decision 2 makes
that schema bi-planar with **disjoint rows**. So a PAT issued on the control plane is simply not
present in the data plane's identity tables, and a shared verifier key does not change that. The
shared key enables the *Git front doors* on one plane, not cross-plane credential portability.

What remains is the observation that the issuer is already public. ADR-0095 gave Zitadel its own
internet-facing hostname, `auth-gitfrok.7.solutions`, because its `ExternalDomain` is baked into what
its discovery document advertises. A browser can reach it. So can a data-plane BFF — and doing so is
**outbound from the data plane**, which is the direction ADR-0011 permits; the rule it protects is
that a *control* plane never reaches *into* a customer's cluster.

## Decision

**1. A data-plane deployment runs its own OIDC login, against the same issuer.** It redirects the
browser to `auth-gitfrok.7.solutions` exactly as the control-plane deployment does, and validates the
resulting ID token against that issuer's published JWKS. This is ordinary OIDC against a public
issuer, not a cross-plane call into control-plane services: no `identityv1.OIDCLogin`, no shared
database, nothing that ADR-0011 forbids.

**2. Sessions are per plane, in a Valkey each plane owns.** Valkey becomes bi-planar, joining
`audit`, `identity` and `policy` in ADR-0101 decision 2's category: two instances of one shape
holding disjoint state. A session on the control plane is not a session on the data plane, is never
replicated, and is never read across the boundary.

**3. One login, because the issuer is shared — not because the session is.** The browser authenticates
once at the issuer; each plane's first request then completes its own OIDC exchange against that
existing SSO session and mints its own cookie. The user is not prompted twice. This is what makes
decision 2's cost acceptable, and it is a property of the shared issuer rather than of any shared
state between planes.

**4. `OIDCLogin` stays where ADR-0100 decision 1 put it, and the data plane does not need it.** That
service is the backend's OIDC helper for the control plane's own flow. Decision 1's assignment stands
unamended; decision 1 above simply does not route through it. ADR-0101's register row asking whether
`OIDCLogin` belongs control-plane-side at all remains open and is not answered here.

**5. The data plane's Valkey is not optional, and its absence is fatal at startup.** ADR-0052
decision 4 already makes a configured-but-unreachable store fatal, and that rule applies unchanged:
a data-plane BFF that cannot reach its session store must refuse to start rather than serve a
repository surface that silently forgets every user.

## Consequences

**Positive:**
- SPEC-0070 AC6 becomes achievable: a data-plane deployment can serve the repository surface to an
  authenticated person, which is the point of ADR-0094 decision 3.
- No shared session store and no cross-plane call, so ADR-0011 stands unamended — the property that
  makes BYO worth its cost.
- Decision 3 means the split costs the user nothing visible; SSO at the issuer does the work.
- It reuses ADR-0095's decision rather than needing a new surface: the issuer is already public and
  already has its own hostname for exactly this kind of reason.
- Decision 2 keeps one rule for all per-plane state instead of a special case for sessions.

**Negative / costs:**
- **A customer's data plane now depends on the vendor's issuer being reachable.** If
  `auth-gitfrok.7.solutions` is down, nobody can log in to their own repository surface — even though
  the repositories, the Git front doors and the data are entirely in their cluster. Git over SSH and
  PAT-authenticated HTTP are unaffected (ADR-0043's credentials resolve locally), so this degrades
  the browser surface rather than the whole plane, but it is a real availability coupling and it is
  the main cost of this ADR.
- **Another Valkey to run** on every data plane, with ADR-0099 decision 4's single-replica posture
  and the session loss that implies.
- **Two cookies, two session lifetimes.** Revoking a session on one plane does not revoke it on the
  other, and nothing enumerates a person's sessions across both.
- The data-plane BFF gains OIDC client configuration — issuer, client id, redirect URI — which is
  per-install state a customer must be given or must register.

**Follow-ups:**
- **The implementing spec and task**: the data-plane BFF's OIDC configuration, its Valkey, and
  SPEC-0070 AC6's remaining half.
- **Valkey in `deploy/k8s/platform/overlays/prod-dp`**, which ADR-0099's table did not give it.
- **Whether the data plane's OIDC client is per-tenant or per-install**, and who registers it with
  Zitadel — adjacent to ADR-0094's unanswered row about the data-plane door's published contract.
- **What a customer sees when the issuer is unreachable** (the first cost). A repository surface that
  says "sign-in is unavailable" is very different from one that looks broken.
- Whether session revocation should span planes, per the third cost.

## Alternatives considered

- **A control-plane-issued credential verified offline data-side**, reusing the shared
  `gitfrok-pat-verifier`. The shape this ADR's context set out to take. Rejected on measurement:
  ADR-0043 resolves credentials through a database gateway and ADR-0101 decision 2 gives each plane
  disjoint identity rows, so a control-issued PAT is not present data-side. Making it work would mean
  either a self-contained signed token — a second credential model beside ADR-0043's — or replicating
  identity rows across planes, which is a cross-plane data path by another name.
- **A shared Valkey both planes reach.** One session, one store, no second login. Rejected: it is a
  datastore reachable from both planes, so a customer's data plane depends on the vendor's session
  store for every request, and a compromise on either side reaches the other's sessions. ADR-0092
  decision 2 and ADR-0011 exist to prevent exactly this.
- **The data-plane BFF calls the control plane's `OIDCLogin`.** Smallest change, reuses decision 1's
  service. Rejected: it is a data-plane process making a synchronous call into control-plane
  internals on the login path, which couples availability in the direction BYO is meant to avoid —
  and unlike decision 1's public issuer, it is an internal service with no published contract.
- **The data plane runs its own Zitadel.** Full independence, no vendor dependency at login.
  Rejected: identity is multi-tenant and control-plane-side by ADR-0093 and ADR-0045, a second issuer
  means a second identity namespace per customer, and tenant mapping (ADR-0045's resource-owner
  claims) would have nothing to map against.
- **No browser surface on the data plane**, serving only Git and an API. Rejected: it abandons
  ADR-0094 decision 3, which moved the repository surface there precisely so that source never
  enters a vendor process.
