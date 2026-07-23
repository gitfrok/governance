    # SPEC-0006: Identity & access (Zitadel + PATs)

    - **Status:** Approved
    - **Owner:** platform
    - **Context(s):** Identity&Access
    - **ADRs:** 0003, 0006
    - **Task(s):** T-0013

    ## Problem / context
    Establish tenant-scoped identity via Zitadel and personal access tokens for git + API.

    ## In scope
    - OIDC/SAML login → tenant-scoped principal; SCIM provisioning; PAT issuance/verification.
- Tenant-context propagation into every request (deny on missing — SPEC-0001 AC2).

    ## Out of scope
    - Fine-grained org role management UI (later).

    ## Contracts touched
    Auth/session/PAT types in `governance/contracts` (additive).

    ## Data owned
    Identity&Access owns identities/tokens; authorization is delegated to the PDP (SPEC-0002).

    ## Acceptance criteria (each becomes a test)
    - [ ] AC1: OIDC login yields a tenant-scoped principal; PATs authenticate git + API.
- [ ] AC2: Every request carries a tenant context; missing → **deny** (no data).
- [ ] AC3: Permission checks go through the **PDP**, never inline.
- [ ] AC4: A cross-tenant principal is rejected.

    ## Governance mapping (G1–G9)
    | Objective | How |
|---|---|
| G1 isolation | tenant-scoped principals |
| G2 least privilege | PDP-mediated authZ |
| G5 auditability | auth events audited |

    ## Non-functional
    Token verification O(1) on hot path; session revocation propagates promptly.

    ## Open questions / assumptions
    - SCIM scope for MVP to confirm.
