## Summary
<!-- What and why -->

## Type of change
- [ ] Feature
- [ ] Fix
- [ ] Refactor
- [ ] Docs / chore

## Architecture decisions — SOT is `docs/adr/` (ADR-0001)
- [ ] This change makes **no** architecturally-significant decision, **OR**
- [ ] I added/updated an ADR in `docs/adr/` → link: ______
- [ ] Any decision this replaces is marked `Superseded by ADR-XXXX`
- [ ] **Status is right for what merging this means.** If merging *is* the approval (ADR-0001 step 3),
      the ADR says `Accepted` and the spec says `Approved` **in this PR**. If you are proposing and
      stopping, `Proposed` is correct and a later PR flips it. Getting this wrong is silent: it has
      happened to ADR-0038, ADR-0039, and ADR-0040.
- [ ] Change traces to a governance objective (G1–G9) where applicable

## Governance / security checklist (ADR-0002)
- [ ] Tenant isolation preserved — no cross-tenant access (G1)
- [ ] Access enforced at the PDP, deny-by-default (G2)
- [ ] Audit events emitted for sensitive actions (G5)
- [ ] Policies-as-code updated if access/approval/compliance rules changed (G4/G6)

## Testing
- [ ] Tests added/updated
- [ ] Isolation / policy tests pass

<!-- GitLab variant: place this file at .gitlab/merge_request_templates/Default.md -->
