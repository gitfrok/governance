# SPEC-0019: Merge request, review, and branch-protection contract

- **Status:** Approved
- **Owner:** platform
- **Context(s):** Code Review, Repository/Git, Policy, Audit
- **ADRs:** 0004, 0006, 0007, 0022
- **Task(s):** T-0016; T-0018 (consumer)
- **PRD:** PR-10

## Problem / context

SPEC-0009 requires merge requests, review-gated protected branches, policy-as-code, and
immutable audit evidence. It deliberately leaves the shared boundary unspecified. Without a
contract, Code Review would either read Repository/Git's storage, duplicate Git-ref authorization,
or encode an approval decision in the BFF. This specification defines the additive boundary before
implementation.

## In scope

- An additive internal Code Review gRPC surface for opening, reading, reviewing, merging, and
  configuring exact-ref branch protection on a tenant-scoped repository.
- A merge-request lifecycle of `OPEN`, `CLOSED`, and `MERGED`; a merge is terminal and a closed
  request cannot be reviewed or merged.
- Server-owned optimistic versioning and request-id idempotency for every mutating command.
- Protection data owned by Code Review and emitted as an event; Repository/Git uses its local,
  tenant-scoped projection only to provide facts to the PDP for a direct-push decision.
- PDP decisions, not inline permission checks, for opening, reviewing, merging, and changing
  branch protection; server-derived policy context identifies a direct push, target ref, whether
  it is protected, and the current valid approval count.
- Immutable audit events for accepted review approvals and merges, correlated to the PDP decision
  ID. Denials remain the existing PDP denial-audit path.

## Out of scope

- Review threads, line comments, merge queues/trains, auto-merge, draft requests, arbitrary
  wildcard branch patterns, browser routes, and Git object transport.
- A default protected-branch rule. A tenant/repository administrator must explicitly configure a
  rule; picking a product default remains the open question in SPEC-0009.
- An authorization outcome supplied by a caller, a BFF, or an event payload. The PDP alone
  answers allow or deny.
- Import provenance and imported approval eligibility; T-0018 extends this surface additively.

## Contracts touched

Additive `contracts/proto/codereview/v1/codereview.proto` contains a
`MergeRequestService` with these internal operations:

- `CreateMergeRequest`, `GetMergeRequest`, `SubmitReview`, `MergeMergeRequest`, and
  `SetBranchProtection`.
- Every request has required context carrying tenant ID, repository ID, verified actor ID,
  verified actor roles, and request ID. Empty or cross-tenant context is a coarse denial. Actor
  and roles come from authenticated identity; the caller cannot assert them.
- A merge request has an opaque ID; opaque source and target `refs/heads/...` ref names; title,
  description, creator, state, current head revision, creation/update time, and a server-assigned
  positive version. No filesystem location, credential, Git pack bytes, policy outcome, or audit
  sequence is representable.
- `SubmitReview` accepts one of `APPROVE`, `REQUEST_CHANGES`, or `COMMENT`, plus bounded text.
  An actor has one current review per merge request; a later submission supersedes that actor's
  current disposition without mutating prior audit evidence. Only an `APPROVE` against the
  current head revision is a valid approval.
- `MergeMergeRequest` accepts only the opaque merge-request ID and expected version. It does not
  accept a target ref, commit SHA, approval count, policy result, or force flag. Code Review asks
  the PDP with server-derived state, then invokes Repository/Git through a contract boundary to
  perform the ref move.
- `SetBranchProtection` accepts an exact `refs/heads/...` target ref and non-negative required
  approval count. It is a replace operation guarded by expected version; branch-pattern syntax is
  intentionally absent from v1. Zero approvals can protect a branch from direct pushes while
  permitting policy-authorized merges.

The contract also defines additive Code Review events: `MergeRequestOpened`, `ReviewSubmitted`,
`MergeRequestMerged`, and `BranchProtectionChanged`. Events carry opaque IDs and tenant/repository
scope, never review text, credentials, Git objects, or a policy allow flag. Repository/Git consumes
only `BranchProtectionChanged` into a local projection; it neither reads Code Review tables nor
calls Code Review on the receive-pack hot path. `BranchProtectionChanged.actor_id` carries the
verified subject of the authorized `SetProtection` that produced the change, so a cross-process
consumer can re-derive that identity when it applies its own PDP decision for the rule.

The policy follow-up adds this reviewed vocabulary:

| Action | Resource type | Server-derived context |
| --- | --- | --- |
| `merge_request.open` | `repository` | source and target ref |
| `merge_request.review` | `merge_request` | current state and head revision |
| `merge_request.merge` | `merge_request` | target ref, protected flag, valid/required approvals |
| `repo.write` | `repository` | operation=`direct_push`, target ref, protected flag |
| `repository.branch_protection.manage` | `repository` | target ref and required approvals |

`protected` and approval-count values are facts produced by Code Review state/projection, never
claims from gRPC, HTTP, Git protocol, or a policy caller. A protected direct push is denied by
policy; a PDP-allowed merge is the only route that can update its target ref.

## Data owned

Code Review owns merge-request state, reviews, branch-protection records, idempotency keys, and
its event payloads. Repository/Git owns Git refs and a projection of branch-protection facts needed
to ask the PDP before accepting a direct ref update. Policy owns authorization and Audit owns
immutable records. No context reads another context's tables.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A tenant-scoped principal can open a request from one source ref to one target ref,
  submit a review, and merge an open request only at its current expected version; replaying a
  request ID is idempotent and stale versions change no state.
- [ ] AC2: An authenticated principal cannot create, read, review, merge, configure protection,
  or consume an event for another tenant; every such failure is coarse and non-enumerating.
- [ ] AC3: A direct receive-pack update to an explicitly protected ref is denied through the PDP,
  while a PDP-approved merge with required current-head approvals updates that same ref.
- [ ] AC4: A changed head revision invalidates every prior approval for merge-policy input; an
  approval from a different head cannot satisfy the rule.
- [ ] AC5: Every authorization-sensitive command receives a PDP decision with server-derived
  context. No API, BFF, event, or Git request can carry an `allowed`, approval-count, or
  protection-result assertion.
- [ ] AC6: An accepted approval and an accepted merge append exactly one immutable audit record
  each, with tenant, actor, merge-request resource, action, outcome, request ID, and decision ID;
  a PDP denial uses the existing immutable denial record and does not mutate MR state.
- [ ] AC7: Contract and boundary tests prove Code Review never accesses Repository/Git storage,
  and Repository/Git obtains protection only from its tenant-scoped event projection.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | every command, event, projection, and PDP request is tenant-scoped |
| G2 least privilege | PDP controls sensitive actions; protected direct writes have no bypass |
| G4 change governance | branch-protection and approval rules are reviewed policy, not code defaults |
| G5 auditability | approvals and merges create immutable, decision-correlated evidence |
| G9 least-privilege footprint | boundaries expose opaque identifiers and facts, never storage, pack, or credential data |

## Non-functional

- Mutations are serializable per merge request or branch-protection record and idempotent per
  tenant, actor, command, and request ID.
- Protection-projection delivery may lag, so a missing, stale, malformed, or tenant-mismatched
  projection fails closed for a target that is known protected; implementation must not replace it
  with a synchronous table read or a fail-open fallback.
- Caller-visible denial and not-found errors do not distinguish nonexistent, cross-tenant, and
  unauthorized merge-request or branch state.

## Open questions / assumptions

- SPEC-0009's default protected-branch ruleset remains a human product decision. This contract
  permits explicit exact-ref rules but does not invent a default such as `main`.
- Concrete merge strategy and conflict presentation are Repository/Git implementation details if
  they preserve the lifecycle, PDP gate, and target-ref constraints. A user-visible strategy
  choice requires a follow-up spec amendment.
- T-0018 adds provenance to review data and must ensure only first-party approvals count in the
  server-derived `valid_approvals` context.
