# SPEC-0055: Policy visibility — what is in force, at what revision, and what decided a given outcome

- **Status:** Approved (2026-08-19) — ADR-0073 Accepted; RED may begin
- **Owner:** platform
- **Context(s):** Policy (owns the bundle and the decision records) · BFF · Web frontend
- **ADRs:** 0073 (decides this), 0001 (governance is the Source of Truth — the reason authoring is
  absent), 0006, 0007, 0070, 0069
- **Task(s):** T-0062 (contract + bff), T-0063 (web)

## Problem / context

PR-16 requires a policy to be **authored, versioned, dry-run and enforced**, with the deciding
version recorded. Three of those exist and one of them is invisible: policies ship as a signed OPA
bundle at a revision, `EvaluateDryRun` is a contract surface, and every decision record already
carries the deciding bundle revision and the input digest.

**Authoring does not exist and ADR-0073 explains why it is structural rather than missing.** Policies
live in `governance/policies/` and ADR-0001 makes governance the Source of Truth; a web form that
writes policy is a second source of truth for the same decisions. That decision is deferred.

So this spec ships the read half — and its central obligation is to be **honest about the half that
is missing**, to a persona who will reasonably expect it. PR-16's user is a compliance owner, and
ADR-0073 records the risk plainly: telling that person to open a pull request against a Rego bundle
may be exactly what this product exists not to do. The surface should not paper over that.

## In scope

- The policy bundle in force: its revision, and when it was loaded.
- A decision record by id: the action, the resource, the outcome, the deciding bundle revision, the
  input digest, and the mode.
- A plain statement of where policy is authored, and that it is not authored here.

## Out of scope

- **Authoring, editing, drafting or uploading a policy**, by ADR-0073. Not as a form, not as an
  upload, not as a disabled control.
- **Dry-running a draft.** `EvaluateDryRun` answers for the policy that exists; a draft would need
  the draft to exist, which is the deferred decision.
- Rendering Rego source. The bundle is a platform artifact and its contents are not a tenant read.

## Contracts touched

`contracts/proto/policy/v1` — **additive**: `GetBundleStatus` returning the revision in force and
when it was loaded. `GetDecision` already exists and is reused unchanged.

## Data owned

None.

## Acceptance criteria (each becomes a test)

### The wire and the BFF (T-0062)

- [x] **AC1** `GetBundleStatus` returns the revision in force and its load time. Additive; `buf
      breaking` passes.
- [x] **AC2** **The contract carries no authoring verb.** A descriptor test asserts
      `PolicyDecisionPoint` has no RPC whose name begins `Put`, `Create`, `Update`, `Delete` or
      `Author` — ADR-0073's deferral as a type property, so it cannot arrive as a convenience before
      the per-tenant policy source is decided.
- [x] **AC3** The BFF shapes and forwards under the session; one coarse refusal. A decision record
      the caller may not read is absent, not forbidden.

### The view (T-0063)

- [x] **AC4** The policy surface renders the bundle revision in force and when it was loaded.
- [x] **AC5** A decision record renders its action, resource, outcome, deciding revision, input
      digest and mode — which is PR-16's "the deciding policy version is recorded on the decision",
      made visible for the first time.
- [x] **AC6** **The absence of authoring is stated plainly and accurately.** The copy says policy is
      authored in the governance repository and not here. A test enumerates it: no rendered string
      may say "coming soon", "not yet supported", or imply the capability exists behind a permission
      the reader lacks — the reader is not missing a role, the product is missing a feature.
- [x] **AC7** No disabled control, no greyed-out form, nothing that looks like authoring waiting to
      be unlocked. A test asserts the markup contains no `disabled` control on this surface.
- [x] **AC8** Outcome and mode carry glyph and word through `src/lib/status.ts`; allow and deny are
      not encoded as a green/red pair.
- [x] **AC9** No hex literal; units on every length; the two regression pins unmodified.
- [x] **AC10** The stub serves both reads and a refusal; captures regenerated and reviewed in
      grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G4 change control | The deciding revision on a decision stops being a database fact only an engineer can reach. |
| G6 evidence | A compliance owner can see what was in force when a decision was taken, which is the question an auditor asks. |
| G2 authorization | AC3 — a decision record outside the caller's reach is absent, not refused with a reason. |

## Non-functional

- Server-rendered, as every other surface in this phase.

## Open questions / assumptions

1. **The compliance-owner persona may not be served by this.** ADR-0073 says so in its own risk
   section. This spec ships the honest read half; it does not claim to close PR-16.
2. **Bundle contents are not rendered**, so a reader sees that a revision decided their case without
   seeing what that revision says. That is a real limit of the read half and is recorded here rather
   than discovered.
