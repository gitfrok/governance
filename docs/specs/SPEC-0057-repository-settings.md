# SPEC-0057: Repository settings — a name, a description, an archive label, and a record of who changed it

- **Status:** Implemented (2026-08-19) — AC1–AC20 green; backend@6fe014c, governance@9122a0d, bff@f7d6067, webfrontend@dc8307e
- **Owner:** platform
- **Context(s):** Repository (owns the registry record these settings live on) · Audit (records the
  change) · BFF · Web frontend — ADR-0022
- **ADRs:** 0076 (decides this and its scope), 0071 (the registry as the truth for existence, which
  this extends), 0007 (append-only audit), 0006 (deny-by-default PDP), 0010, 0022, 0069, 0027
- **Task(s):** T-0068 (backend), T-0069 (contract + bff), T-0070 (web)

## Problem / context

PR-30 asks that a repository owner can read and change repository settings — name, description,
visibility, members and archival — each change audited. ADR-0076 accepted **name, description and
archival only**, because the other two are authorization-model changes wearing a form's clothing:
"public" is not a setting but a different authorization model, and per-repository membership is a new
one the PDP would have to learn everywhere `repo.read` is asked.

What remains is smaller than the prototype shows and is genuinely the product's: a repository already
has a name in the registry ADR-0071 made durable, and nothing has ever been able to change it. Today
`Save` converges on the name it was given, and its own comment says a rename is PR-30's job.

**The reason this surface is worth building carefully is not what it does, it is what it attracts.**
PR-10 says branch protection and approval requirements are enforced server-side and expressed as
policy, not UI toggles. A settings page is exactly where that sentence erodes — not by decision, but
by a "require approvals" checkbox appearing where a user would look for one. This spec therefore
spends more of its acceptance criteria on what the surface cannot express than on what it can.

## In scope

- Reading a repository's settings: name, description, archived state, and when each was last changed
  and by whom.
- Changing the name and the description.
- Archiving and unarchiving, as a **label** — see the archival rule below.
- One audit record per accepted change, and one per refusal that reached the PDP.

## Out of scope

- **Visibility**, by ADR-0076 decision 2. Not a field, not a disabled control, not a "coming soon".
  A disabled control tells a reader they lack a permission; they do not, because the capability does
  not exist (SPEC-0055 AC7's rule).
- **Members and per-repository roles**, by the same decision. Roles are tenant-level and PDP-decided
  (ADR-0049).
- **Branch protection, approval requirements and merge rules.** PR-10 puts them in
  `governance/policies`, and ADR-0073 has already deferred tenant authoring of those.
- **Deletion**, by ADR-0076 decision 3. The registry's application role has no `DELETE` grant and its
  migration names PR-30 as the reason; that stays true.
- **Archival as enforcement.** See below — it is the assumption most likely to be misread.

## The archival rule

**An archived repository is labelled, not restricted.** Archiving records a fact and renders it;
pushes are not refused, reads are not narrowed, no PDP input gains a field, and no surface becomes
read-only.

This is not timidity, it is the shape of the product. A repository that refuses writes is a
**read-only condition**, and a read-only condition here must name its cause from a two-member
vocabulary — the PR-7 durability mode and an envelope throttle (SPEC-0046 AC4,
`repository/api/readonly.go`). Adding a third member is a decision about the git write path and its
audited-override semantics, not a setting, and `readonly-cause` is a phase-wide regression pin so
that it cannot be widened as a side effect of a feature. An archive that refuses pushes is a real
requirement; it is a different one, and it returns to ADR-0076.

## Contracts touched

- `contracts/proto/repository/v1` — **additive**: a new `RepositorySettings` service with
  `GetSettings`, `UpdateSettings` and `SetArchived`.

It is a third service in the package rather than RPCs on `RepositoryRegistry`, for the reason
`RepositoryRegistry` is separate from `RepositoryReader`: a service is the surface one process
serves. The registry answers *which repositories exist for a caller* and is deliberately
unwidenable — it has no field a caller could use to ask differently (ADR-0071 decision 4). Settings
name one repository and change it. Putting a write verb on the listing service would put a mutation
behind the one surface whose whole property is that it cannot be steered.

## Data owned

The Repository context's existing `repo.repositories` table gains `description`, `archived_at`,
`settings_updated_at` and `settings_updated_by`. Module-owned migration, additive, RLS unchanged —
the table already has it, keyed on `tenant_id`.

No new table: settings are properties of the registry record, and a second table keyed on the same
identity would be a second answer to "does this repository exist".

## Acceptance criteria (each becomes a test)

### The backend (T-0068)

- [x] **AC1** `GetSettings` returns one repository's name, description, archived state and the
      instant/actor of the last settings change. It is a `repo.read` PDP decision; a repository in
      another tenant is **absent**, not forbidden (invariant 1, SPEC-0001).
- [x] **AC2** `UpdateSettings` changes name and description and nothing else. The name is required
      and non-empty — the registry's `CHECK (name <> '')` and `domain.NewRepository` both say so, and
      a rename to empty is refused rather than stored.
- [x] **AC3** `SetArchived` sets or clears the archived instant. Archiving an archived repository is
      the same fact stated twice and is accepted idempotently, **without** a second audit record and
      without moving the recorded instant.
- [x] **AC4** **Every accepted change appends exactly one audit record**, naming the actor, the
      repository, and *which* fields changed — `repository.settings.updated` for a name or
      description change and `repository.archival.changed` for an archive act. The record carries the
      new values, never a diff of prose the caller did not send.
- [x] **AC5** **A settings change is refused unless the PDP allows it**, and the refusal is a coarse
      one: a caller who may not write a repository's settings learns nothing about whether it exists.
      A refusal that reached the PDP is audited with `OutcomeDenied`.
- [x] **AC6** **The audit record is written through a port this context declares**, not by importing
      the Audit context. Repository is a leaf at fan-out zero (T-0009's graph report) and stays one:
      the composition root adapts the trail onto the port, exactly as it does for Residency's witness
      and for the registry's `Authorizer`.
- [x] **AC7** **Archival changes no authorization or read outcome.** A test archives a repository and
      asserts: it still appears in the caller's list, `Get` still returns it, and its
      `ReadOnlyState` is unchanged and writable. The assertion is the ADR-0076 decision-1 boundary in
      executable form.
- [x] **AC8** The new columns are additive over the existing registry; the migration passes T-0004's
      boundary linter; settings survive a process restart; a cross-tenant settings write is refused
      before any database work, as `scoped` already refuses one.
- [x] **AC9** **The isolation proofs ran.** Zero skips for the tenancy cases; the exit record states
      the observed skip count (carried limit 5).

### The wire and the BFF (T-0069)

- [x] **AC10** Additive: `buf breaking` passes; `RepositorySettings` is a new service and no existing
      message changes shape.
- [x] **AC11** **No message in `repository/v1` carries a visibility, membership or policy field.** A
      descriptor check asserts the absence of `visibility`, `public`, `private`, `member`, `members`,
      `branch_protection`, `protected_branch`, `required_approvals`, `approval_rule`, `merge_rule` and
      `permissions`, with a fixture carrying `visibility` to prove the check can fail. ADR-0076
      decision 1 and 2 as a type property: a policy control on this surface cannot arrive quietly.
- [x] **AC12** **No delete verb reaches the repository surface.** The same check asserts no RPC named
      `Delete*` in `repository/v1` — ADR-0076 decision 3, alongside the registry migration's revoked
      `DELETE` grant, so the absence holds at the wire as well as at the table.
- [x] **AC13** The BFF shapes and forwards under the session: a read, a settings write, and an
      archive act. The actor comes from the session and has no field on the request. Every failure is
      one coarse refusal, except a rename to empty, which is a 400 about the field the caller sent.
- [x] **AC14** The BFF response body carries no visibility, member, role or protection vocabulary. A
      test asserts it, so the accepted increment holds at the layer a browser actually reads rather
      than only in the contract.

### The view (T-0070)

- [x] **AC15** The settings page shows name, description and archived state, each editable by a plain
      form that works with no client script, and states who last changed the settings and when.
- [x] **AC16** **The page states what it does not do, and the copy enumeration forbids the softer
      phrasings.** It says visibility and membership are not repository settings in this product and
      that branch protection and approval requirements are policy, not toggles — and the test forbids
      "coming soon", "not yet available", "upcoming", "planned" and any phrasing implying a control
      is pending. There is no disabled control anywhere on the page.
- [x] **AC17** **An archived repository says what archival does and does not do**: the label is
      shown, and the copy says the repository is still readable and still writable. A test asserts
      the page renders no read-only vocabulary for an archived repository — the AC7 boundary, at the
      layer a person reads it.
- [x] **AC18** Description renders as text, not as HTML. A description containing markup is
      displayed, not executed — the same rule SPEC-0056 AC14 set for release notes, and for the same
      reason.
- [x] **AC19** No hex literal; every status word in `src/lib/status.ts` with a glyph and a word;
      archived and active are separable in grayscale and under deuteranopia; the two regression pins
      unmodified.
- [x] **AC20** The stub serves a plain repository and an archived one; captures regenerated per
      SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | The settings read and write are tenant-scoped through the registry's existing RLS and its `scoped` refusal; a cross-tenant repository is absent. |
| G2 authorization | Every act is a PDP decision on the repository. This surface adds no permission, no role and no per-repository authorization model — AC11 makes that a contract property. |
| G5 auditability | One record per accepted change and one per PDP-reached refusal, naming actor, repository and fields (AC4, AC5). |
| G6 policy as code | AC11 and AC12 keep branch protection, approval requirements and deletion off this surface, which is where PR-10 would otherwise erode. |

## Non-functional

- The description is bounded at the column and at the contract. It is prose about a repository, not a
  document store.

## Open questions / assumptions

1. **Archival is a label.** The strongest reading of PR-30 is that archiving makes a repository
   read-only. That is a git-write-path decision with a read-only cause behind it, and this increment
   deliberately does not take it — see the archival rule above.
2. **Renaming does not move anything.** The registry's name is a display name; clone URLs are keyed
   on the repository ID, which does not change. A rename that changed a URL would be a redirect
   decision, and there is no redirect surface.
3. **`settings_updated_by` is an actor ID, not a name.** Resolving it to a person is the identity
   context's job and no surface here asks it to.
