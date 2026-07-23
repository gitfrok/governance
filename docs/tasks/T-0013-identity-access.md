    # T-0013: Identity & access: Zitadel + PATs

    - **Status:** Todo
    - **Phase / Epic:** 1 / MVP
    - **Repo(s):** backend + governance (contracts)
    - **Spec:** docs/specs/SPEC-0006-identity-access.md (base: SPEC-0001)
    - **ADRs:** 0003, 0006
    - **Owner:** unassigned

    ## Goal
    Wire Zitadel (OIDC/SAML/SCIM) and personal access tokens into tenant-scoped identity.

    ## Acceptance criteria (test-first)
    - [ ] AC1: OIDC login yields a tenant-scoped principal; PATs authenticate git + API.
- [ ] AC2: every request carries a tenant context; missing context → deny (SPEC-0001 AC2).
- [ ] AC3: token/permission checks go through the **PDP**, never inline.

    ## Tests to write first
    - unit: token/session; contract: auth types in governance/contracts (additive); integration: Zitadel.
- policy/isolation: deny-by-default; cross-tenant principal rejected.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
    Cross-repo changes follow the ADR-0027 order (governance first).
