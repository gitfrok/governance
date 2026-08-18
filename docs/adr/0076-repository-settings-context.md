# ADR-0076: Repository settings is where policy quietly becomes a UI toggle, and PR-10 forbids that

- **Status:** Proposed
- **Date:** 2026-08-19
- **Deciders:** platform (required by ADR-0070's follow-up before any PR-30 spec)
- **Related:** ADR-0070, ADR-0006 (deny-by-default PDP), ADR-0003 (tenancy), ADR-0007 (audit),
  ADR-0022, ADR-0071, ADR-0073 (the sibling deferral for policy authoring), ADR-0049 (identity)
- **Governs:** PR-30

## Context

The prototype shows repository Settings with General, Members, Visibility, and a Danger zone
carrying `Archive project` and `Delete this project`. PR-30 asks that a repository owner can read
and change name, description, visibility, members and archival, each change audited.

Unlike Issues and Releases, this is not mostly a new context — most of what it edits already exists.
That makes it look like the cheapest Tier C item. It is the most dangerous one, for a reason the PRD
already states.

**PR-10: "Branch protection and approval requirements are enforced server-side and expressed as
policy, not UI toggles."** A repository settings page is precisely where that sentence erodes. Not
by anyone deciding to break it — by a settings page growing a "require approvals" checkbox because
it is obviously where a user would look for one.

Three of the five fields carry their own problem.

**Visibility.** "Public" may not exist in this product. Everything is tenant-scoped, and every read
is a PDP decision with a verified caller (ADR-0003, ADR-0006); an unauthenticated public read is not
a setting, it is a different authorization model with its own hole in invariant 1's shape.

**Members.** Roles today are tenant-level, from Zitadel — owner, member, reader (ADR-0049, the
usability chain). Per-repository membership is a **new authorization model**, and the PDP would need
to know about it everywhere `repo.read` is asked, which is everywhere.

**Delete.** A repository holds tenant data referenced by audit records, evidence packs, findings,
CI runs and a durable registry (ADR-0071). Deleting it is not a row removal; it is a question about
what survives, and the audit log is append-only by ADR-0007, so some of it must.

## Decision

**This ADR does not adopt repository settings. It fixes three boundaries.**

**1. No setting on this surface may change an authorization or policy outcome.** Name, description
and archival state are properties. Branch protection, approval requirements and merge rules are
policy, and PR-10 puts them in `governance/policies` — where ADR-0073 has already deferred tenant
authoring. A settings page that grows a policy control is the ADR-0073 deferral being routed around,
and this decision names that in advance because it will not look like routing around it at the time.

**2. Visibility is not a setting until "public" is a decided authorization model.** Until then the
field is absent rather than present-and-disabled, following SPEC-0055 AC7's rule: a disabled control
tells a reader they lack a permission, and they do not — the capability does not exist.

**3. Deletion is out of scope for PR-30. Archival is the reachable half.** Archiving is a property
change with an audit record. Deletion is a data-lifecycle decision spanning audit, evidence,
residency and retention, and it is the one operation in this product that cannot be undone by an
operator.

## Consequences

**Good.** The PR-10 erosion is named before a checkbox exists. Archival gives the surface a real
purpose without opening the deletion question.

**Bad.** A settings page without visibility, members or deletion is close to a rename form, and a
customer looking at it will reasonably ask what it is for.

**The risk this ADR is most likely to be wrong about.** That per-repository membership can wait.
Tenant-level roles mean anyone who can read one repository can read all of them, which is a coarser
model than most customers assume they are buying, and no amount of careful settings design fixes it.
If that is the real gap, PR-30 is the wrong frame entirely and the work belongs in the authorization
model rather than in a settings page.

## Alternatives considered

**Ship the full settings page including visibility and members.** Refused: both are authorization
model changes wearing a form's clothing.

**Ship nothing until per-repository authorization is decided.** Defensible, and the honest reading
if the risk above holds. The middle path — name, description, archival — is chosen because it is
real, auditable and forecloses nothing.

## Follow-ups

- Whether per-repository membership is needed, which is an authorization decision and not a settings
  one.
- What "public" would mean, if anything.
- Repository deletion: what survives it, and what the audit log's append-only guarantee requires.
