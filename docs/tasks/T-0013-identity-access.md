# T-0013: Identity & access: Zitadel + PATs

- **Status:** Done (2026-08-10) — PAT/SSH + OIDC login both landed
- **Phase / Epic:** 1 / EP-5 Identity
- **Repo(s):** backend + governance (contracts)
- **Spec:** docs/specs/SPEC-0006-identity-access.md; docs/specs/SPEC-0016-identity-credential-contract.md; docs/specs/SPEC-0022-ssh-verifier-key-routing.md
- **ADRs:** 0003, 0006, 0043, **0045**
- **Owner:** unassigned

## Goal
Wire Zitadel (OIDC/SAML/SCIM) and personal access tokens into tenant-scoped identity.

## Acceptance criteria (test-first)
- [x] AC1: OIDC login yields a tenant-scoped principal; PATs authenticate git + API. (PAT/SSH ✓; OIDC ✓)
- [x] AC2: every request carries a tenant context; missing context → deny (SPEC-0001 AC2).
- [x] AC3: token/permission checks go through the **PDP**, never inline.
- [x] AC4: cross-tenant principals are rejected.

## Tests to write first
- unit: token/session; contract: auth types in governance/contracts (additive); integration: Zitadel.
- policy/isolation: deny-by-default; cross-tenant principal rejected.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record (credential foundation)

| Repo | Commit | What |
|---|---|---|
| backend | `1e6d6b7` (#21) | Tenant-scoped credential foundation: `modules/identity/` with PAT/SSH key authentication, HMAC keyed verifier ring, tenant-scoping, PDP-gated lifecycle (issue/revoke/list), RLS-backed credential store, and gRPC `CredentialAuthenticator` surface. |
| governance | `9b79511` (#78) | Additive identity credential authentication contract in `contracts/proto/identity/v1/`. |
| governance | `e3d6628` (#84) | Additive verified actor roles field in the identity contract. |
| governance | `0d8bb98` (#90) | ADR-0043 Accepted — credential verifiers resolved through a narrow RLS gateway. |
| governance | `e0500bb` (#92) | SPEC-0022 Approved — SSH verifier key ID routing. |
| governance | `24a27e0` (#96) | ADR-0045 Proposed → Accepted (2026-08-10) — Zitadel verified claims map to tenant-scoped principals. |

- **AC1 (PAT/SSH)** — `AuthenticatePAT`/`AuthenticateSSHKey` return tenant-scoped `Principal`; tenant context bound to URL tenant. `modules/identity` tests pass (`go test -race ./modules/identity/...`).
- **AC2** — `tenancy.Require` in identity lifecycle; front-door `RoutePAT`/`RouteSSH` enforce `principal.TenantID == tenantID`; cross-tenant → `ErrDenied`.
- **AC3** — all lifecycle operations route through `s.authorizeLifecycle` → `policyapi.Request` (the PDP). The `inline_authz` fitness function (T-0002/T-0009) verifies no inline permission checks outside `modules/policy`.
- **AC4** — `ErrTenantMismatch` rejects cross-tenant principals at the router.

## Remaining work: Zitadel OIDC login

ADR-0045 (Accepted 2026-08-10) specifies Authorization Code Flow with PKCE. **This is now landed:**

| Repo | Commit | What |
|---|---|---|
| backend | `25edba5` (#37) | OIDC login: `modules/identity` OIDC server + verifier (`ExchangeCode`, `VerifyIDToken`), claim→principal mapping per ADR-0045, wired into `cmd/dataplane-app` behind `GITFROK_OIDC_*` env; `modules/identity/internal/oidc` tests pass |
| governance | `2d50133` (#108) | Additive `identity_oidc.proto` — the OIDC login verification surface (ExchangeCode/VerifyIDToken) |

**The BFF web-session half** (turning an OIDC login into the browser session the web surface needs) is T-0015's work, on bff PR #22: an opaque server-side cookie per ADR-0049, the /login → /callback → /logout flow with PKCE, and the session resolved to a tenant-scoped `ReadContext` on every request. The web session is the last integration point; SCIM scope remains an open question in SPEC-0006.

## Notes / open questions
SPEC-0006 and SPEC-0016 were Approved before implementation. Cross-repo changes followed ADR-0027 order (governance first). SCIM scope for MVP remains an open question in SPEC-0006.
